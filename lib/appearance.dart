import 'package:material_ui/material_ui.dart';

import 'actions.dart';
import 'design.dart';
import 'domain.dart';
import 'theme_settings.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key, required this.actions});
  final HavenActions actions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: actions.store,
    builder: (context, _) {
      final state = actions.store.state;
      final settings = state.appearance;
      final colors = palette(context);
      void save(ThemeSettings next, {ThemePreference? mode}) => actions.run(
        context,
        (state) => state.copyWith(
          appearance: next,
          theme: mode,
          appearanceUpdatedAt: DateTime.now().microsecondsSinceEpoch,
        ),
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Appearance')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                _Preview(colors: colors),
                const SizedBox(height: 18),
                Text('Theme presets', style: displayStyle(context, size: 24)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final preset in ThemePreset.values)
                      ChoiceChip(
                        selected:
                            settings.preset == preset &&
                            settings.mono == Mono.off,
                        label: Text(preset.label),
                        onSelected: (_) => save(
                          settings.copyWith(
                            preset: preset,
                            mono: Mono.off,
                            base: preset == ThemePreset.custom
                                ? settings.base
                                : preset,
                          ),
                        ),
                      ),
                    ChoiceChip(
                      selected: settings.mono != Mono.off,
                      label: const Text('Black & White'),
                      onSelected: (on) => save(
                        settings.copyWith(
                          mono: on ? settings.monoVariant : Mono.off,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Panel(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DropdownButtonFormField<ThemePreference>(
                        key: ValueKey(state.theme),
                        initialValue: state.theme,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Color mode',
                        ),
                        items: [
                          for (final mode in ThemePreference.values)
                            DropdownMenuItem(
                              value: mode,
                              child: Text(switch (mode) {
                                ThemePreference.system => 'System',
                                ThemePreference.light => 'Light',
                                ThemePreference.dark => 'Dark',
                              }),
                            ),
                        ],
                        onChanged:
                            settings.mono == Mono.off &&
                                settings.preset != ThemePreset.dark
                            ? (mode) => save(settings, mode: mode)
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Black & White'),
                        value: settings.mono != Mono.off,
                        onChanged: (on) => save(
                          settings.copyWith(
                            mono: on ? settings.monoVariant : Mono.off,
                          ),
                        ),
                      ),
                      if (settings.mono != Mono.off)
                        DropdownButtonFormField<Mono>(
                          key: ValueKey(settings.mono),
                          initialValue: settings.mono,
                          decoration: const InputDecoration(
                            labelText: 'Monochrome variant',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: Mono.white,
                              child: Text('White'),
                            ),
                            DropdownMenuItem(
                              value: Mono.black,
                              child: Text('Black'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              save(
                                settings.copyWith(
                                  mono: value,
                                  monoVariant: value,
                                ),
                              );
                            }
                          },
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('High contrast'),
                        value: settings.highContrast,
                        onChanged: (value) =>
                            save(settings.copyWith(highContrast: value)),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reduced motion'),
                        value: settings.reducedMotion,
                        onChanged: (value) =>
                            save(settings.copyWith(reducedMotion: value)),
                      ),
                      Row(
                        children: [
                          const Expanded(child: Text('Font size')),
                          Text('${(settings.fontScale * 100).round()}%'),
                        ],
                      ),
                      Slider(
                        min: .85,
                        max: 1.35,
                        divisions: 10,
                        value: settings.fontScale,
                        label: '${(settings.fontScale * 100).round()}%',
                        semanticFormatterCallback: (value) =>
                            '${(value * 100).round()} percent font size',
                        onChanged: (value) =>
                            save(settings.copyWith(fontScale: value)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Custom colors', style: displayStyle(context, size: 24)),
                const SizedBox(height: 6),
                if (settings.mono != Mono.off)
                  const Text('Turn off Black & White to edit your colors.')
                else
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        for (final token in ThemeToken.values)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _Swatch(colors[token]),
                            title: Text(token.label),
                            subtitle: Text(_hex(colors[token])),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final choice = await showDialog<int>(
                                context: context,
                                builder: (_) => _ColorEditor(
                                  token: token,
                                  state: state,
                                  initial: colors[token],
                                ),
                              );
                              if (choice != null && context.mounted) {
                                final latest = actions.store.state.appearance;
                                save(
                                  latest.copyWith(
                                    preset: ThemePreset.custom,
                                    base: latest.preset == ThemePreset.custom
                                        ? latest.base
                                        : latest.preset,
                                    colors: {...latest.colors, token: choice},
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => save(
                      const ThemeSettings(),
                      mode: ThemePreference.system,
                    ),
                    child: const Text('Restore default theme'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const SizedBox(width: 26, height: 26),
  );
}

class _Preview extends StatelessWidget {
  const _Preview({required this.colors});
  final HavenPalette colors;
  @override
  Widget build(BuildContext context) {
    final background = colors[ThemeToken.background];
    final surface = colors[ThemeToken.surface];
    final ink = readableColor(colors[ThemeToken.text], surface);
    final mono = colors.monochrome;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(15),
          border: mono ? Border.all(color: ink) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Preview',
              style: displayStyle(context, size: 23).copyWith(color: ink),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: .7,
              color: readableColor(
                colors[ThemeToken.progress],
                surface,
                minRatio: 3,
              ),
              backgroundColor: Color.lerp(ink, surface, .82),
              semanticsLabel: 'Example progress',
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final (token, name) in const [
                  (ThemeToken.todo, 'Todo'),
                  (ThemeToken.routine, 'Routine'),
                  (ThemeToken.event, 'Event'),
                  (ThemeToken.my, 'My'),
                  (ThemeToken.more, 'More'),
                ])
                  Container(
                    decoration: BoxDecoration(
                      color: mono ? surface : colors[token],
                      border: Border.all(
                        color: mono ? ink : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        color: readableColor(
                          ink,
                          mono ? surface : colors[token],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorEditor extends StatefulWidget {
  const _ColorEditor({
    required this.token,
    required this.state,
    required this.initial,
  });
  final ThemeToken token;
  final HavenState state;
  final Color initial;
  @override
  State<_ColorEditor> createState() => _ColorEditorState();
}

class _ColorEditorState extends State<_ColorEditor> {
  late HSLColor color = HSLColor.fromColor(widget.initial);
  late final TextEditingController hex = TextEditingController(
    text: _hex(widget.initial),
  );
  bool valid = true;

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  void setColor(HSLColor next) => setState(() {
    color = next;
    valid = true;
    hex.text = _hex(color.toColor());
  });

  @override
  Widget build(BuildContext context) {
    final current = widget.state.appearance;
    final value = color.toColor().toARGB32() & 0xffffff;
    final preview = current.copyWith(
      preset: ThemePreset.custom,
      base: current.preset == ThemePreset.custom
          ? current.base
          : current.preset,
      colors: {...current.colors, widget.token: value},
    );
    return AlertDialog(
      title: Text(widget.token.label),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Preview(
              colors: makePalette(Theme.of(context).brightness, preview),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.toColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hex,
              decoration: InputDecoration(
                labelText: 'Hex color',
                errorText: valid ? null : 'Enter six hexadecimal digits.',
              ),
              onChanged: (text) {
                final input = text.trim().replaceFirst('#', '');
                final next = int.tryParse(input, radix: 16);
                setState(() {
                  valid = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(input);
                  if (valid) color = HSLColor.fromColor(rgb(next!));
                });
              },
            ),
            for (final (name, amount, max, update) in [
              ('Hue', color.hue, 360.0, color.withHue),
              ('Saturation', color.saturation, 1.0, color.withSaturation),
              ('Lightness', color.lightness, 1.0, color.withLightness),
            ]) ...[
              Text(name),
              Slider(
                value: amount,
                max: max,
                semanticFormatterCallback: (value) =>
                    '$name ${(value / max * 100).round()} percent',
                onChanged: (value) => setColor(update(value)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, value) : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
