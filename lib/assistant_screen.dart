import 'package:material_ui/material_ui.dart';

import 'assistant.dart';
import 'design.dart';
import 'domain.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.session,
    required this.state,
  });

  final AssistantSession session;
  final HavenState state;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final input = TextEditingController();

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sent = await widget.session.send(input.text, widget.state);
    if (sent && mounted) input.clear();
  }

  Future<void> _settings() async {
    final settings = await showDialog<AssistantSettings>(
      context: context,
      builder: (context) => _AssistantSettingsDialog(widget.session.settings),
    );
    if (!mounted || settings == null) return;
    try {
      await widget.session.configure(settings);
    } on Object {
      if (mounted) showNotice(context, 'Could not save the Ollama settings.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final session = widget.session;
      final settings = session.settings;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageIntro(
            'AI assistant',
            'Plan your week or break a task into steps.',
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings == null ? 'Connect Ollama' : settings.model,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  settings == null
                      ? 'Use a model running on your computer or server.'
                      : settings.server.host,
                  style: muted(context),
                ),
                OutlinedButton(
                  onPressed: session.busy ? null : _settings,
                  child: Text(
                    settings == null
                        ? 'Set up Ollama'
                        : 'Change server or model',
                  ),
                ),
              ],
            ),
          ),
          if (settings != null) ...[
            SwitchListTile(
              title: const Text('Include this week’s tasks'),
              subtitle: const Text(
                'Send task titles and progress to Ollama with your next message.',
              ),
              value: session.includingTasks,
              onChanged: session.busy ? null : session.includeTasks,
            ),
            for (final message in session.messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.role == 'user' ? 'You' : 'Haven',
                        style: muted(context),
                      ),
                      const SizedBox(height: 5),
                      SelectableText(message.content),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: input,
              enabled: !session.busy,
              minLines: 1,
              maxLines: 5,
              maxLength: 1500,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Help me plan my week',
              ),
            ),
            if (session.error case final error?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (session.busy)
              const LinearProgressIndicator(
                semanticsLabel: 'Waiting for Ollama',
              ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: session.busy ? null : _send,
                  child: Text(session.busy ? 'Thinking…' : 'Send'),
                ),
                if (session.messages.isNotEmpty)
                  TextButton(
                    onPressed: session.busy ? null : session.reset,
                    child: const Text('Clear chat'),
                  ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

class _AssistantSettingsDialog extends StatefulWidget {
  const _AssistantSettingsDialog(this.initial);
  final AssistantSettings? initial;

  @override
  State<_AssistantSettingsDialog> createState() =>
      _AssistantSettingsDialogState();
}

class _AssistantSettingsDialogState extends State<_AssistantSettingsDialog> {
  late final server = TextEditingController(
    text: widget.initial?.server.toString(),
  );
  late final model = TextEditingController(text: widget.initial?.model);
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    server.dispose();
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ollama settings'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 400,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: server,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://192.168.1.10:11434',
                  helperText: 'Use a local network address or HTTPS.',
                ),
                validator: (value) => ollamaServer(value ?? '') == null
                    ? 'Enter a valid Ollama server URL.'
                    : null,
              ),
              const SizedBox(height: 11),
              TextFormField(
                controller: model,
                autocorrect: false,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'qwen3:0.6b',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the name from ollama list.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              AssistantSettings.parse(server.text, model.text),
            );
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
