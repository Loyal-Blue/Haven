import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'actions.dart';
import 'assistant.dart';
import 'design.dart';
import 'domain.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.session,
    required this.state,
    required this.actions,
  });

  final AssistantSession session;
  final HavenState state;
  final HavenActions actions;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final input = TextEditingController();
  bool selectingPhoto = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final sent = await widget.session.send(input.text, widget.state);
    if (sent && mounted) input.clear();
  }

  Future<void> settings() async {
    final setup = await showDialog<AssistantSettings>(
      context: context,
      builder: (_) => _AssistantSettingsDialog(widget.session.settings),
    );
    if (!mounted || setup == null) return;
    try {
      await widget.session.configure(setup);
    } on Object {
      if (mounted) showNotice(context, 'Could not save AI provider settings.');
    }
  }

  Future<void> photo(ImageSource source) async {
    final config = widget.session.settings;
    if (config == null || selectingPhoto) return;
    setState(() => selectingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;
      if (await picked.length() > 4 * 1024 * 1024) {
        if (mounted) showNotice(context, 'Choose an image smaller than 4 MB.');
        return;
      }
      final bytes = await picked.readAsBytes();
      final mime = _mime(bytes);
      if (!mounted) return;
      if (mime == null) {
        showNotice(context, 'Choose a JPEG, PNG, or WebP image.');
        return;
      }
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Create tasks from this photo?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.memory(
                bytes,
                height: 170,
                fit: BoxFit.contain,
                semanticLabel: 'Selected photo',
              ),
              const SizedBox(height: 10),
              Text(
                'Send this image to ${config.provider.label} and add the extracted tasks for today.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create tasks'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      final titles = await widget.session.tasksFromPhoto((
        bytes: bytes,
        mime: mime,
      ));
      if (titles == null || !mounted) return;
      var added = 0;
      final result = await widget.actions.run(context, (state) {
        final today = dayKey(DateTime.now());
        final seen = state.tasks
            .where((task) => !task.archived)
            .map((task) => task.title.toLowerCase())
            .toSet();
        final tasks = [
          for (final title in titles)
            if (seen.add(title.toLowerCase()))
              Task(id: newId(), title: title, due: today, createdOn: today),
        ];
        added = tasks.length;
        return tasks.isEmpty
            ? state
            : state.copyWith(tasks: [...state.tasks, ...tasks]);
      });
      if (mounted && result != null) {
        showNotice(
          context,
          added == 0
              ? 'No new tasks found in the photo.'
              : 'Added $added ${added == 1 ? 'task' : 'tasks'} for today.',
        );
      }
    } on Object {
      if (mounted) {
        showNotice(context, 'Could not open the selected photo or camera.');
      }
    } finally {
      if (mounted) setState(() => selectingPhoto = false);
    }
  }

  String? _mime(List<int> data) {
    if (data.length < 12) return null;
    if (data[0] == 0xff && data[1] == 0xd8 && data[2] == 0xff) {
      return 'image/jpeg';
    }
    if (data[0] == 0x89 && String.fromCharCodes(data.sublist(1, 4)) == 'PNG') {
      return 'image/png';
    }
    if (String.fromCharCodes(data.take(4)) == 'RIFF' &&
        String.fromCharCodes(data.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final session = widget.session;
      final setup = session.settings;
      final locked = session.busy || selectingPhoto;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageIntro('Haven AI', ''),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setup == null
                      ? 'Connect an AI provider'
                      : setup.provider.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (setup != null) Text(setup.model, style: muted(context)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: locked ? null : settings,
                  child: Text(
                    setup == null ? 'Set up provider' : 'Provider settings',
                  ),
                ),
                if (setup != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      if (Platform.isAndroid || Platform.isIOS)
                        FilledButton.icon(
                          onPressed: locked
                              ? null
                              : () => photo(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Take photo'),
                        ),
                      OutlinedButton.icon(
                        onPressed: locked
                            ? null
                            : () => photo(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose photo'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (setup != null) ...[
            SwitchListTile(
              title: const Text('Include this week’s tasks'),
              subtitle: Text(
                'Share task and project titles and progress with ${setup.provider.label}.',
              ),
              value: session.includingTasks,
              onChanged: locked ? null : session.includeTasks,
            ),
            if (session.messages.isEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (label, prompt) in const [
                    (
                      'Plan my week',
                      'Suggest a realistic schedule for my week.',
                    ),
                    (
                      'Organize a project',
                      'Help me break down and organize a project.',
                    ),
                    (
                      'Weekly summary',
                      'Summarize this week and suggest one improvement.',
                    ),
                    (
                      'Town growth',
                      'Explain the town growth based on weekly completion.',
                    ),
                  ])
                    ActionChip(
                      label: Text(label),
                      onPressed: locked ? null : () => input.text = prompt,
                    ),
                ],
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
              enabled: !locked,
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
                semanticsLabel: 'Waiting for AI provider',
              ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: locked ? null : send,
                  child: Text(session.busy ? 'Thinking…' : 'Send'),
                ),
                if (session.messages.isNotEmpty)
                  TextButton(
                    onPressed: locked ? null : session.reset,
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
  late AIProvider provider = widget.initial?.provider ?? AIProvider.ollama;
  late final server = TextEditingController(
    text: widget.initial?.server.toString() ?? provider.address,
  );
  late final model = TextEditingController(
    text: widget.initial?.model ?? provider.model,
  );
  late final key = TextEditingController(text: widget.initial?.key);
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    server.dispose();
    model.dispose();
    key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('AI provider settings'),
    scrollable: true,
    content: SizedBox(
      width: 400,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<AIProvider>(
              initialValue: provider,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: [
                for (final option in AIProvider.values)
                  DropdownMenuItem(value: option, child: Text(option.label)),
              ],
              onChanged: (selected) {
                if (selected == null || selected == provider) return;
                setState(() {
                  provider = selected;
                  server.text = selected.address;
                  model.text = selected.model;
                  key.clear();
                });
              },
            ),
            const SizedBox(height: 11),
            if (provider == AIProvider.ollama ||
                provider == AIProvider.compatible) ...[
              TextFormField(
                controller: server,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Server URL'),
                validator: (value) =>
                    AssistantSettings.parse(
                          value ?? '',
                          'model',
                          provider: provider,
                          key: key.text,
                        ) ==
                        null
                    ? 'Enter a valid URL. Use HTTPS with an API key.'
                    : null,
              ),
              const SizedBox(height: 11),
            ],
            TextFormField(
              controller: model,
              autocorrect: false,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Model'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter a model name.' : null,
            ),
            if (provider != AIProvider.ollama) ...[
              TextFormField(
                controller: key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'API key'),
                validator: (value) =>
                    provider.usesKey && (value ?? '').trim().isEmpty
                    ? 'Enter your API key.'
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Keys stay in memory until Haven closes. API usage is billed separately from ChatGPT and Claude subscriptions.',
                style: muted(context),
              ),
            ],
          ],
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
              AssistantSettings.parse(
                server.text,
                model.text,
                provider: provider,
                key: key.text,
              ),
            );
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
