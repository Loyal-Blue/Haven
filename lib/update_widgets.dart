import 'package:material_ui/material_ui.dart';

import 'design.dart';
import 'updates.dart';

class UpdatesPanel extends StatelessWidget {
  const UpdatesPanel(this.updates, {super.key});
  final UpdateController updates;

  Future<void> _editFeed(BuildContext context) async {
    final initial = updates.feed?.toString() ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _FeedEditor(initial),
    );
    if (value == null || !context.mounted) return;
    try {
      await updates.configure(
        feed: updateFeedUri(value),
        automatic: updates.automatic,
      );
    } on Object {
      if (context.mounted) {
        showNotice(context, 'Could not save the update feed.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final feed = updates.feed;
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.system_update_alt_outlined),
              contentPadding: EdgeInsets.zero,
              title: const Text('Updates'),
              subtitle: Text(
                'Haven ${updates.version} · Build ${updates.build}',
              ),
            ),
            Text(
              feed == null
                  ? 'Add an HTTPS release feed to receive updates.'
                  : 'Release feed · ${feed.host}',
              style: muted(context),
            ),
            if (feed != null) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Automatic updates'),
                subtitle: Text(
                  updates.platform == 'android'
                      ? 'Download in the app. Android asks you to install.'
                      : updates.canInstall
                      ? 'Download now and apply on the next launch.'
                      : 'Check for new versions when Haven is open.',
                ),
                value: updates.automatic,
                onChanged: updates.busy
                    ? null
                    : (enabled) async {
                        try {
                          await updates.configure(
                            feed: feed,
                            automatic: enabled,
                          );
                        } on Object {
                          if (context.mounted) {
                            showNotice(
                              context,
                              'Could not save update settings.',
                            );
                          }
                        }
                      },
              ),
              if (updates.status case final status?) ...[
                const SizedBox(height: 5),
                Semantics(
                  liveRegion: true,
                  child: Text(status, style: muted(context)),
                ),
              ],
              if (updates.available != null && !updates.canInstall)
                Text(
                  'Use the packaged Linux launcher for automatic installs.',
                  style: muted(context),
                ),
              if (updates.busy) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  semanticsLabel: 'Update in progress',
                ),
              ],
              const SizedBox(height: 7),
            ],
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: updates.busy ? null : () => _editFeed(context),
                  child: Text(
                    feed == null ? 'Set release feed' : 'Edit release feed',
                  ),
                ),
                if (feed != null)
                  TextButton(
                    onPressed: updates.busy
                        ? null
                        : () => updates.check(force: true),
                    child: const Text('Check now'),
                  ),
                if (updates.available != null &&
                    updates.canInstall &&
                    (updates.platform == 'android' || !updates.ready))
                  FilledButton(
                    onPressed: updates.busy ? null : updates.install,
                    child: const Text('Install update'),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class UpdateNotice extends StatelessWidget {
  const UpdateNotice(this.updates, {super.key, required this.openSettings});
  final UpdateController updates;
  final VoidCallback openSettings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final release = updates.available;
      if (release == null || updates.busy) return const SizedBox.shrink();
      final text = updates.ready && updates.platform != 'android'
          ? 'Haven ${release.version} will open next launch'
          : 'Haven ${release.version} is available';
      return Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: InkWell(
          onTap: openSettings,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.system_update_alt_outlined, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _FeedEditor extends StatefulWidget {
  const _FeedEditor(this.initial);
  final String initial;

  @override
  State<_FeedEditor> createState() => _FeedEditorState();
}

class _FeedEditorState extends State<_FeedEditor> {
  late final controller = TextEditingController(text: widget.initial);
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Release feed'),
    content: SizedBox(
      width: 400,
      child: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'HTTPS manifest URL',
            helperText: 'Leave empty to disable updates.',
          ),
          autocorrect: false,
          validator: (value) =>
              (value ?? '').trim().isNotEmpty && updateFeedUri(value!) == null
              ? 'Enter a valid HTTPS URL.'
              : null,
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
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: const Text('Save feed'),
      ),
    ],
  );
}
