import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/updates.dart';

const platform = 'linux-x64';

Map<String, dynamic> manifest({
  int build = 3,
  String url = 'https://releases.example.test/haven.tar.gz',
  String digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
}) => {
  'schema': 1,
  'version': '0.2.1',
  'build': build,
  'artifacts': {
    platform: {'url': url, 'sha256': digest, 'bytes': 128},
  },
};

Future<File> testArchive(Directory temp, {bool traversal = false}) async {
  const prefix = 'Haven-Linux/versions/3/';
  final archive = Archive();
  const entries = {
    'haven': '#!/bin/sh\nexit 0\n',
    'lib/libapp.so': 'App payload',
    'lib/libflutter_linux_gtk.so': 'Engine payload',
    'data/icudtl.dat': 'Unicode data',
    'data/flutter_assets/version.json':
        '{"app_name":"haven","build_number":"3"}',
  };
  for (final item in entries.entries) {
    archive.addFile(ArchiveFile.string('$prefix${item.key}', item.value));
  }
  if (traversal) {
    archive.addFile(
      ArchiveFile.string('${prefix}data/../../outside', 'unexpected'),
    );
  }
  return File('${temp.path}/test.tar.gz')
      .writeAsBytes(gzip.encode(TarEncoder().encode(archive)));
}

class _FixtureClient extends UpdateClient {
  const _FixtureClient(this.release, this.file);

  final UpdateRelease release;
  final File file;

  @override
  Future<UpdateRelease?> latest(Uri feed, String platform, int build) async =>
      release;

  @override
  Future<File> download(UpdateRelease release, File destination) async {
    await destination.parent.create(recursive: true);
    final copied = await file.copy(destination.path);
    if (!await verifies(copied, release)) {
      throw const FormatException('Fixture mismatch');
    }
    return copied;
  }
}

void main() {
  test('parse only newer releases with a valid HTTPS artifact', () {
    final result = UpdateRelease.parse(manifest(), platform, 2);
    expect(result?.build, 3);
    expect(UpdateRelease.parse(manifest(), platform, 3), isNull);
    expect(UpdateRelease.parse(manifest(), 'android', 2), isNull);
    expect(updateFeedUri('https://owner:secret@example.test/feed'), isNull);
    expect(
      () => UpdateRelease.parse(
        manifest(url: 'http://example.test/app'),
        platform,
        2,
      ),
      throwsFormatException,
    );
  });

  test(
    'checksum verification refuses altered content of the same length',
    () async {
      final temp = await Directory.systemTemp.createTemp('haven-verification-');
      addTearDown(() => temp.delete(recursive: true));
      final bytes = utf8.encode('Haven');
      final release = UpdateRelease(
        '0.2.1',
        3,
        Uri.https('example.test'),
        sha256.convert(bytes).toString(),
        bytes.length,
      );
      final file = await File('${temp.path}/test.apk').writeAsBytes(bytes);
      const client = UpdateClient();
      expect(await client.verifies(file, release), isTrue);
      await file.writeAsString('Raven');
      expect(await client.verifies(file, release), isFalse);
    },
  );

  test('automatic Linux update stages a new version and retains the previous bundle', () async {
    final temp = await Directory.systemTemp.createTemp('haven-updates-');
    addTearDown(() => temp.delete(recursive: true));
    final older = await Directory('${temp.path}/versions/2')
        .create(recursive: true);
    await File('${older.path}/haven').writeAsString('original');
    await File('${temp.path}/haven').writeAsString('launcher');
    final pointer = await File('${temp.path}/current').writeAsString('2\n');
    final archive = await testArchive(temp);
    final release = UpdateRelease(
      '0.2.1',
      3,
      Uri.https('example.test'),
      (await sha256.bind(archive.openRead()).first).toString(),
      await archive.length(),
    );
    final linux = LinuxUpdateTarget.detect('${older.path}/haven', 2);
    expect(linux, isNotNull);
    final controller = UpdateController(
      settings: File('${temp.path}/settings.json'),
      cache: Directory('${temp.path}/cache'),
      version: '0.2.0',
      build: 2,
      platform: platform,
      linux: linux,
      client: _FixtureClient(release, archive),
    );
    addTearDown(controller.dispose);
    await controller.configure(
      feed: Uri.https('example.test', 'haven-updates.json'),
      automatic: true,
    );
    expect(controller.ready, isTrue, reason: controller.status);
    expect(await pointer.readAsString(), '3\n');
    expect(await File('${older.path}/haven').readAsString(), 'original');
    final executable = await File('${temp.path}/versions/3/haven').stat();
    expect(executable.mode & 0x40, isNonZero);
    await controller.check(force: true);
    expect(await pointer.readAsString(), '3\n');
  }, skip: !Platform.isLinux);

  test('invalid Linux payload leaves the active launcher intact', () async {
    final temp = await Directory.systemTemp.createTemp(
      'haven-update-rejected-',
    );
    addTearDown(() => temp.delete(recursive: true));
    await Directory('${temp.path}/versions/2').create(recursive: true);
    final pointer = await File('${temp.path}/current').writeAsString('2\n');
    final archive = await testArchive(temp, traversal: true);
    final release = UpdateRelease(
      '0.2.1',
      3,
      Uri.https('example.test'),
      (await sha256.bind(archive.openRead()).first).toString(),
      await archive.length(),
    );
    await expectLater(
      LinuxUpdateTarget(temp).stage(archive, release),
      throwsA(anything),
    );
    expect(await pointer.readAsString(), '2\n');
    expect(await Directory('${temp.path}/versions/3').exists(), isFalse);
    expect(await File('${temp.path}/versions/outside').exists(), isFalse);
  }, skip: !Platform.isLinux);
}
