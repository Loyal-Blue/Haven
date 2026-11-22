enum ThemePreset {
  classic('Haven Classic', 0x396850, 0x5d7290, 0xf1eee8, 0xfbf8f1),
  lavender('Lavender', 0x685186, 0x8a608b, 0xf1eaf5, 0xfdf9ff),
  ocean('Ocean', 0x265f87, 0x316e6d, 0xe8f0f3, 0xf6fbfc),
  sunset('Sunset', 0x963e39, 0x80512e, 0xf8ebe3, 0xfff6ec),
  forest('Forest', 0x355e3f, 0x655c34, 0xe9eadc, 0xf5f2e4),
  dark('Dark', 0xb9d9c1, 0xc2cbea, 0x1b2020, 0x272d2b),
  custom('Custom', 0x396850, 0x5d7290, 0xf1eee8, 0xfbf8f1);

  const ThemePreset(
    this.label,
    this.primary,
    this.secondary,
    this.background,
    this.surface,
  );
  final String label;
  final int primary, secondary, background, surface;
}

enum Mono { off, white, black }

enum ThemeToken {
  primary('Primary accent'),
  secondary('Secondary accent'),
  background('Background'),
  surface('Cards and surfaces'),
  text('Text'),
  navigation('Navigation'),
  progress('Progress'),
  town('Town environment'),
  todo('Todo tab'),
  routine('Routine tab'),
  event('Event tab'),
  my('My tab'),
  more('More tab');

  const ThemeToken(this.label);
  final String label;
}

class ThemeSettings {
  const ThemeSettings({
    this.preset = ThemePreset.classic,
    this.base = ThemePreset.classic,
    this.mono = Mono.off,
    this.monoVariant = Mono.white,
    this.colors = const {},
    this.fontScale = 1,
    this.reducedMotion = false,
    this.highContrast = false,
  });
  final ThemePreset preset, base;
  final Mono mono, monoVariant;
  final Map<ThemeToken, int> colors;
  final double fontScale;
  final bool reducedMotion, highContrast;

  ThemeSettings copyWith({
    ThemePreset? preset,
    ThemePreset? base,
    Mono? mono,
    Mono? monoVariant,
    Map<ThemeToken, int>? colors,
    double? fontScale,
    bool? reducedMotion,
    bool? highContrast,
  }) => ThemeSettings(
    preset: preset ?? this.preset,
    base: base ?? this.base,
    mono: mono ?? this.mono,
    monoVariant: monoVariant ?? this.monoVariant,
    colors: colors == null ? this.colors : Map.unmodifiable(colors),
    fontScale: fontScale ?? this.fontScale,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    highContrast: highContrast ?? this.highContrast,
  );

  Map<String, dynamic> toJson() => {
    'preset': preset.name,
    'base': base.name,
    'mono': mono.name,
    'monoVariant': monoVariant.name,
    'colors': {for (final entry in colors.entries) entry.key.name: entry.value},
    'fontScale': fontScale,
    'reducedMotion': reducedMotion,
    'highContrast': highContrast,
  };

  factory ThemeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ThemeSettings();
    final colors = json['colors'];
    final scale = json['fontScale'];
    return ThemeSettings(
      preset:
          ThemePreset.values
              .where((v) => v.name == json['preset'])
              .firstOrNull ??
          ThemePreset.classic,
      base:
          ThemePreset.values
              .where((v) => v != ThemePreset.custom && v.name == json['base'])
              .firstOrNull ??
          ThemePreset.classic,
      mono:
          Mono.values.where((v) => v.name == json['mono']).firstOrNull ??
          Mono.off,
      monoVariant: json['monoVariant'] == 'black' ? Mono.black : Mono.white,
      colors: Map.unmodifiable({
        if (colors is Map)
          for (final token in ThemeToken.values)
            if (colors[token.name] is int &&
                (colors[token.name] as int) >= 0 &&
                (colors[token.name] as int) <= 0xffffff)
              token: colors[token.name] as int,
      }),
      fontScale: scale is num ? scale.toDouble().clamp(.85, 1.35) : 1,
      reducedMotion: json['reducedMotion'] == true,
      highContrast: json['highContrast'] == true,
    );
  }
}
