import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _platformUpdates = MethodChannel('app.havenlife.haven/updates');
const _defaultFeed = String.fromEnvironment(
  'HAVEN_UPDATE_FEED',
  defaultValue: 'https://github.com/Loyal-Blue/Haven/releases/latest/download/haven-updates.json',
);
const _downloadLimit = 160 * 1024 * 1024;
const _networkTimeout = Duration(seconds: 25);

Uri? updateFeedUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    return null;
  }
  return uri;
}

class UpdateRelease {
  const UpdateRelease(
    this.version,
    this.build,
    this.url,
    this.sha256,
    this.bytes,
  );

  final String version;
  final int build;
  final Uri url;
  final String sha256;
  final int bytes;

  static UpdateRelease? parse(
    Object? json,
    String platform,
    int installedBuild,
  ) {
    if (json is! Map<String, dynamic> || json['schema'] != 1) {
      throw const FormatException('Unsupported update feed.');
    }
    final build = json['build'];
    final version = json['version'];
    final artifacts = json['artifacts'];
    if (build is! int ||
        build < 1 ||
        build > 2100000000 ||
        version is! String ||
        !RegExp(r'^\d{1,6}\.\d{1,6}\.\d{1,6}$').hasMatch(version) ||
        artifacts is! Map<String, dynamic>) {
      throw const FormatException('Invalid release metadata.');
    }
    if (build <= installedBuild || !artifacts.containsKey(platform)) {
      return null;
    }
    final artifact = artifacts[platform];
    if (artifact is! Map<String, dynamic>) {
      throw const FormatException('Invalid release file.');
    }
    final url = updateFeedUri(
      artifact['url'] is String ? artifact['url'] as String : '',
    );
    final digest = artifact['sha256'];
    final bytes = artifact['bytes'];
    if (url == null ||
        digest is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
        bytes is! int ||
        bytes < 1 ||
        bytes > _downloadLimit) {
      throw const FormatException('Invalid release download details.');
    }
    return UpdateRelease(version, build, url, digest, bytes);
  }
}

class UpdateClient {
  const UpdateClient();

  Future<UpdateRelease?> latest(Uri feed, String platform, int build) =>
      _response(feed, (response) async {
        final data = <int>[];
        await for (final chunk in response.timeout(_networkTimeout)) {
          if (data.length + chunk.length > 64 * 1024) {
            throw const FormatException('Update feed is too large.');
          }
          data.addAll(chunk);
        }
        return UpdateRelease.parse(
          jsonDecode(utf8.decode(data)),
          platform,
          build,
        );
      });

  Future<bool> verifies(File file, UpdateRelease release) async {
    if (!await file.exists() || await file.length() != release.bytes) {
      return false;
    }
    return (await sha256.bind(file.openRead()).first).toString() ==
        release.sha256;
  }

  Future<File> download(UpdateRelease release, File destination) async {
    if (await verifies(destination, release)) return destination;
    await destination.parent.create(recursive: true);
    final partial = File('${destination.path}.part');
    try {
      await _response(release.url, (response) async {
        var received = 0;
        final output = partial.openWrite();
        try {
          await for (final chunk in response.timeout(_networkTimeout)) {
            received += chunk.length;
            if (received > release.bytes) {
              throw const FormatException('Download size mismatch.');
            }
            output.add(chunk);
          }
        } finally {
          await output.close();
        }
      });
      if (!await verifies(partial, release)) {
        throw const FormatException('Download checksum mismatch.');
      }
      return await partial.rename(destination.path);
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<T> _response<T>(
    Uri uri,
    Future<T> Function(HttpClientResponse) consume,
  ) async {
    final client = HttpClient()..connectionTimeout = _networkTimeout;
    try {
      for (var hops = 0; hops <= 5; hops++) {
        final request = await client.getUrl(uri).timeout(_networkTimeout);
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        final response = await request.close().timeout(_networkTimeout);
        if (response.statusCode == HttpStatus.ok) {
          return await consume(response);
        }
        final location = response.headers.value(HttpHeaders.locationHeader);
        final redirect = location == null
            ? null
            : updateFeedUri(uri.resolve(location).toString());
        if (!response.isRedirect || redirect == null) {
          throw const HttpException('Update request failed.');
        }
        await response.drain<void>().timeout(_networkTimeout);
        uri = redirect;
      }
      throw const HttpException('Too many update redirects.');
    } finally {
      client.close(force: true);
    }
  }
}

class LinuxUpdateTarget {
  const LinuxUpdateTarget(this.root);
  final Directory root;

  static LinuxUpdateTarget? detect(String executable, int build) {
    final bundle = File(executable).parent;
    final versions = bundle.parent;
    final root = versions.parent;
    if (bundle.path != '${root.path}/versions/$build' ||
        !File('${root.path}/haven').existsSync() ||
        !File('${root.path}/current').existsSync()) {
      return null;
    }
    return LinuxUpdateTarget(root);
  }

  Future<void> stage(File archive, UpdateRelease release) async {
    final current = File('${root.path}/current');
    final versions = Directory('${root.path}/versions');
    final target = Directory('${versions.path}/${release.build}');
    final mutex = await File('${root.path}/.update-lock')
        .open(mode: FileMode.append);
    try {
      await mutex.lock(FileLock.exclusive);
      final active = int.tryParse((await current.readAsString()).trim());
      if (active == null || active < 1) {
        throw const FormatException('Invalid Linux launcher.');
      }
      if (active >= release.build) return;
      if (!await target.exists()) {
        final scratch = await versions.createTemp('.incoming-');
        try {
          final scratchPath = scratch.path;
          final archivePath = archive.path;
          final build = release.build;
          await Isolate.run(
            () => _unpackLinux(archivePath, scratchPath, build),
          );
          await File('${scratch.path}/.release-sha256')
              .writeAsString(release.sha256, flush: true);
          await scratch.rename(target.path);
        } finally {
          if (await scratch.exists()) await scratch.delete(recursive: true);
        }
      } else {
        final checksum = File('${target.path}/.release-sha256');
        if (!await checksum.exists() ||
            await checksum.readAsString() != release.sha256) {
          throw const FormatException(
            'Another Linux bundle already uses this build number.',
          );
        }
      }
      await File('${current.path}.part')
          .writeAsString('${release.build}\n', flush: true);
      await File('${current.path}.part').rename(current.path);
    } finally {
      await mutex.close();
    }
  }
}

Future<void> _unpackLinux(String package, String destination, int build) async {
  final tar = File('$destination/.download.tar');
  final stream = File(package).openRead().transform(gzip.decoder);
  final sink = tar.openWrite();
  var expanded = 0;
  try {
    await for (final chunk in stream) {
      expanded += chunk.length;
      if (expanded > 320 * 1024 * 1024) {
        throw const FormatException('Linux bundle is too large.');
      }
      sink.add(chunk);
    }
  } finally {
    await sink.close();
  }

  final input = InputFileStream(tar.path);
  final prefix = 'Haven-Linux/versions/$build/';
  final written = <String>{};
  var declared = 0;
  try {
    TarDecoder().decodeStream(
      input,
      verify: true,
      keepEntries: false,
      callback: (entry) {
        if (!entry.name.startsWith(prefix) || entry.isDirectory) return;
        if (entry.isSymbolicLink || entry.isHardLink) {
          throw const FormatException('Unexpected link in update.');
        }
        final relative = entry.name.substring(prefix.length);
        final components = relative.split('/');
        if (components.any(
              (part) =>
                  part.isEmpty ||
                  part == '.' ||
                  part == '..' ||
                  part.contains('\\'),
            ) ||
            !(relative == 'haven' ||
                components.first == 'data' ||
                components.first == 'lib') ||
            !written.add(relative)) {
          throw const FormatException('Unexpected file in update.');
        }
        declared += entry.size;
        if (declared > 320 * 1024 * 1024 || written.length > 10000) {
          throw const FormatException('Linux update exceeded its size limits.');
        }
        final output = File('$destination/$relative');
        output.parent.createSync(recursive: true);
        final data = OutputFileStream(output.path);
        try {
          entry.writeContent(data);
        } finally {
          data.closeSync();
        }
      },
    );
  } finally {
    await input.close();
    await tar.delete();
  }

  const essential = {
    'haven',
    'lib/libapp.so',
    'lib/libflutter_linux_gtk.so',
    'data/flutter_assets/version.json',
    'data/icudtl.dat',
  };
  if (!written.containsAll(essential)) {
    throw const FormatException('The Linux update is missing required files.');
  }
  final json = jsonDecode(
    await File('$destination/data/flutter_assets/version.json').readAsString(),
  );
  if (json is! Map ||
      json['build_number'] != '$build' ||
      json['app_name'] != 'haven') {
    throw const FormatException(
      'Update bundle build does not match the release.',
    );
  }
  final result = await Process.run('chmod', ['755', '$destination/haven']);
  if (result.exitCode != 0) {
    throw const FileSystemException('Could not prepare the Linux launcher.');
  }
}

class UpdateController extends ChangeNotifier {
  UpdateController({
    required this.settings,
    required this.cache,
    required this.version,
    required this.build,
    required this.platform,
    this.linux,
    this.client = const UpdateClient(),
  });

  final File settings;
  final Directory cache;
  final String version;
  final int build;
  final String platform;
  final LinuxUpdateTarget? linux;
  final UpdateClient client;

  Uri? feed;
  bool automatic = true;
  bool busy = false;
  bool ready = false;
  UpdateRelease? available;
  String? status;
  DateTime? _lastChecked;

  bool get isWindows => platform == 'windows-x64';
  bool get canInstall => platform == 'android' || linux != null;
  bool get canDownload => canInstall || isWindows;

  static Future<UpdateController?> load(
    Directory support,
    Directory cache,
  ) async {
    final String platform;
    final Map<String, dynamic> info;
    if (Platform.isAndroid) {
      platform = 'android';
      info =
          await _platformUpdates.invokeMapMethod<String, dynamic>('version') ??
          {};
    } else if ((Platform.isLinux && Abi.current() == Abi.linuxX64) ||
        (Platform.isWindows && Abi.current() == Abi.windowsX64)) {
      platform = Platform.isWindows ? 'windows-x64' : 'linux-x64';
      info = jsonDecode(
        await rootBundle.loadString('version.json'),
      ) as Map<String, dynamic>;
    } else {
      return null;
    }
    final build = int.tryParse('${info['build_number']}');
    if (build == null || build < 1 || info['version'] is! String) return null;
    final service = UpdateController(
      settings: File('${support.path}/update-settings.json'),
      cache: Directory('${cache.path}/haven-updates'),
      version: info['version'] as String,
      build: build,
      platform: platform,
      linux: platform == 'linux-x64'
          ? LinuxUpdateTarget.detect(Platform.resolvedExecutable, build)
          : null,
    );
    service.feed = updateFeedUri(_defaultFeed);
    try {
      if (await service.settings.exists()) {
        final json = jsonDecode(await service.settings.readAsString());
        if (json is Map) {
          if (json.containsKey('feed')) {
            service.feed = updateFeedUri('${json['feed'] ?? ''}');
          }
          service.automatic = json['automatic'] != false;
        }
      }
    } on Object {
      // A settings file problem should never block opening the town.
    }
    return service;
  }

  Future<void> configure({required Uri? feed, required bool automatic}) async {
    if (busy) return;
    final sourceChanged = this.feed != feed;
    final staging = File('${settings.path}.part');
    await staging.writeAsString(
      jsonEncode({'feed': feed?.toString(), 'automatic': automatic}),
      flush: true,
    );
    await staging.rename(settings.path);
    this.feed = feed;
    this.automatic = automatic;
    if (sourceChanged) {
      available = null;
      ready = false;
      status = null;
      _lastChecked = null;
    }
    notifyListeners();
    if (automatic || sourceChanged) await check(force: true);
  }

  Future<void> check({bool force = false}) async {
    final source = feed;
    if (source == null || busy || (!automatic && !force)) return;
    final now = DateTime.now();
    if (!force &&
        _lastChecked != null &&
        now.difference(_lastChecked!) < const Duration(hours: 6)) {
      return;
    }
    _lastChecked = now;
    await _run('Checking for updates…', () async {
      final release = await client.latest(source, platform, build);
      if (release == null) {
        available = null;
        ready = false;
        status = 'Haven is up to date.';
        return;
      }
      if (available?.sha256 != release.sha256) ready = false;
      available = release;
      status = 'Haven ${release.version} is available.';
      if (automatic && canDownload && !ready) await _prepare(release);
    });
  }

  Future<void> install() async {
    final release = available;
    if (busy || release == null || !canDownload) return;
    await _run('Preparing update…', () async {
      if (!ready || platform == 'android') await _prepare(release);
      if (platform == 'android') {
        final opened = await _platformUpdates.invokeMethod<bool>('install', {
          'filename': _filename(release),
          'build': release.build,
        });
        status = opened == true
            ? 'Confirm the update in the Android installer.'
            : 'Allow installs from Haven in Android Settings, then tap Install update again.';
      } else if (isWindows) {
        final file = File('${cache.path}/${_filename(release)}').absolute;
        await Process.start('explorer.exe', ['/select,${file.path}']);
        status =
            'Extract the verified ZIP, then start Haven from the new folder.';
      }
    });
  }

  String _filename(UpdateRelease release) =>
      'haven-${release.build}.${switch (platform) {
        'android' => 'apk',
        'windows-x64' => 'zip',
        _ => 'tar.gz',
      }}';

  Future<void> _prepare(UpdateRelease release) async {
    status = 'Downloading Haven ${release.version}…';
    notifyListeners();
    final artifact = await client.download(
      release,
      File('${cache.path}/${_filename(release)}'),
    );
    if (linux case final target?) {
      status = 'Preparing update for the next launch…';
      notifyListeners();
      await target.stage(artifact, release);
    }
    ready = true;
    status = switch (platform) {
      'android' =>
        'Haven ${release.version} is downloaded and ready to install.',
      'windows-x64' =>
        'The Haven ${release.version} ZIP is downloaded and verified.',
      _ => 'Haven ${release.version} will open the next time you launch Haven.',
    };
  }

  Future<void> _run(String progress, Future<void> Function() action) async {
    busy = true;
    status = progress;
    notifyListeners();
    try {
      await action();
    } on PlatformException catch (error) {
      status = error.message ?? 'Android could not open the update.';
    } on FormatException catch (error) {
      status = error.message;
    } on Object {
      status = 'Could not update Haven. Check the connection or release feed and try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
