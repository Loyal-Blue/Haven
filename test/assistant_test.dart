import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haven/assistant.dart';
import 'package:haven/domain.dart';

void main() {
  test(
    'Ollama accepts local HTTP or HTTPS and rejects public cleartext URLs',
    () {
      expect(ollamaServer('http://127.0.0.1:11434'), isNotNull);
      expect(ollamaServer('http://192.168.1.5:11434'), isNotNull);
      expect(ollamaServer('http://100.81.2.3:11434'), isNotNull);
      expect(ollamaServer('https://ollama.example.test/ollama'), isNotNull);
      expect(ollamaServer('http://ollama.example.test'), isNull);
      expect(ollamaServer('https://a:b@example.test'), isNull);
    },
  );

  test('task context contains titles and counts without notes or finance', () {
    final now = DateTime(2026, 11, 22);
    final state = HavenState(
      tasks: [
        const Task(
          id: 'test',
          title: 'Read chapter',
          due: '2026-11-22',
          notes: 'private-note',
        ),
      ],
      money: [
        const MoneyEntry(
          'money',
          'private-money',
          'Savings',
          4000,
          MoneyKind.income,
          '2026-11-22',
        ),
      ],
    );
    final context = assistantTaskContext(state, now);
    expect(jsonDecode(context)['task_titles'], ['Read chapter']);
    expect(context, isNot(contains('private-note')));
    expect(context, isNot(contains('private-money')));
  });

  test('chat sends a real Ollama request and shares task context only when enabled', () async {
    final temp = await Directory.systemTemp.createTemp('haven-ai-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await temp.delete(recursive: true);
    });
    final requests = <Map<String, dynamic>>[];
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/chat');
      requests.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'message': {'content': 'Start with five minutes.'},
        }),
      );
      await request.response.close();
    });

    final session = AssistantSession(File('${temp.path}/assistant.json'));
    addTearDown(session.dispose);
    final settings = AssistantSettings.parse(
      'http://127.0.0.1:${server.port}',
      'test-model',
    )!;
    await session.configure(settings);
    final now = DateTime(2026, 11, 22);
    final state = HavenState.starter(now);
    expect(await session.send('Help me plan', state, now: now), isTrue);
    expect(session.messages.last.content, 'Start with five minutes.');
    expect(requests.first['model'], 'test-model');
    expect(requests.first['stream'], isFalse);
    expect(jsonEncode(requests.first), isNot(contains('Clean my room')));

    session.includeTasks(true);
    expect(await session.send('Help me prioritize', state, now: now), isTrue);
    expect(jsonEncode(requests.last), contains('Clean my room'));
    session.includeTasks(false);
    expect(session.messages, isEmpty);
  });
}
