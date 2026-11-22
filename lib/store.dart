import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'domain.dart';

class HavenStore extends ChangeNotifier {
  HavenStore(this.file, this._state);

  final File file;
  HavenState _state;
  Future<void> _pending = Future.value();

  HavenState get state => _state;

  static Future<HavenStore> open(Directory directory, {DateTime? now}) async {
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}haven-v1.json',
    );
    final openedAt = now ?? DateTime.now();
    if (await file.exists()) {
      final existing = HavenState.fromJson(
        jsonDecode(await file.readAsString()) as Json,
      );
      final current = applyTaskReset(
        advanceTownExpansion(existing, openedAt),
        openedAt,
      );
      final store = HavenStore(file, current);
      if (!identical(current, existing)) await store._save(current);
      return store;
    }
    final store = HavenStore(file, HavenState.starter(openedAt));
    await store._save(store.state);
    return store;
  }

  Future<HavenState> commit(HavenState Function(HavenState) change) {
    final operation = _pending.then((_) async {
      final next = change(_state);
      if (identical(next, _state)) return _state;
      await _save(next);
      _state = next;
      notifyListeners();
      return next;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _save(HavenState state) async {
    final staged = File('${file.path}.tmp');
    await staged.writeAsString(jsonEncode(state.toJson()), flush: true);
    await staged.rename(file.path);
  }
}
