import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'domain.dart';
import 'mobile_preferences.dart';
import 'theme_settings.dart';

bool get havenPhone =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class PhoneStyle extends ThemeExtension<PhoneStyle> {
  const PhoneStyle(this.preferences, this.highContrast);
  final MobilePreferences preferences;
  final bool highContrast;

  static const edge = 16.0;
  static const gap = 12.0;
  static const section = 24.0;
  static const radius = 24.0;
  static const touch = 48.0;
  static const maxPageWidth = 620.0;
  static const accent = Color(0xffffbe3d);
  static const paper = Color(0xfff7f6f2);
  static const charcoal = Color(0xff20201f);
  static const darkSurface = Color(0xff2c2b29);

  @override
  PhoneStyle copyWith() => this;
  @override
  PhoneStyle lerp(PhoneStyle? other, double t) => other ?? this;
}

PhoneStyle? phoneStyle(BuildContext context) =>
    Theme.of(context).extension<PhoneStyle>();

Duration phoneMotion(BuildContext context, int milliseconds) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  final intensity = phoneStyle(context)?.preferences.motion.factor ?? 1;
  return Duration(milliseconds: (milliseconds * intensity).round());
}

Color phoneCardColor(BuildContext context, DashboardCard card) {
  final theme = Theme.of(context);
  final tokens = palette(context);
  if (tokens.monochrome) return theme.colorScheme.surface;
  final style = phoneStyle(context);
  final color = rgb(style?.preferences.colors[card] ?? card.color);
  if (theme.brightness == Brightness.light &&
      (!(style?.highContrast ?? false) ||
          color.computeLuminance() >= .30 ||
          color.computeLuminance() <= .10)) {
    return color;
  }
  if (theme.brightness == Brightness.light) {
    return Color.lerp(color, Colors.white, .48)!;
  }
  return Color.lerp(PhoneStyle.darkSurface, color, .28)!;
}

Color phoneInk(BuildContext context, Color background) => readableColor(
  palette(context)[ThemeToken.text],
  background,
  minRatio: (phoneStyle(context)?.highContrast ?? false) ? 7 : 4.5,
);

class HavenPalette extends ThemeExtension<HavenPalette> {
  const HavenPalette(this.colors, this.monochrome, this.reducedMotion);
  final Map<ThemeToken, Color> colors;
  final bool monochrome, reducedMotion;

  Color operator [](ThemeToken token) => colors[token]!;

  @override
  HavenPalette copyWith() => this;

  @override
  HavenPalette lerp(HavenPalette? other, double t) => other == null
      ? this
      : HavenPalette(
          {
            for (final token in ThemeToken.values)
              token: Color.lerp(this[token], other[token], t)!,
          },
          other.monochrome,
          other.reducedMotion,
        );
}

HavenPalette palette(BuildContext context) =>
    Theme.of(context).extension<HavenPalette>() ??
    makePalette(Theme.of(context).brightness, const ThemeSettings());

Color rgb(int value) => Color(0xff000000 | value);

Color readableColor(
  Color preferred,
  Color background, {
  double minRatio = 4.5,
}) {
  final luminance = background.computeLuminance();
  bool passes(Color candidate) {
    final l = candidate.computeLuminance();
    return (math.max(l, luminance) + .05) / (math.min(l, luminance) + .05) >=
        minRatio;
  }

  if (passes(preferred)) return preferred;
  final endpoint = luminance > .179 ? Colors.black : Colors.white;
  for (var i = 1; i < 10; i++) {
    final candidate = Color.lerp(preferred, endpoint, i / 10)!;
    if (passes(candidate)) return candidate;
  }
  return endpoint;
}

HavenPalette makePalette(
  Brightness brightness,
  ThemeSettings settings, {
  bool mobile = false,
}) {
  final base = settings.preset == ThemePreset.custom
      ? settings.base
      : settings.preset;
  final dark = brightness == Brightness.dark || base == ThemePreset.dark;
  final mono = settings.mono;
  if (mono != Mono.off) {
    final black = mono == Mono.black;
    final ink = black ? Colors.white : Colors.black;
    final paper = black ? Colors.black : Colors.white;
    return HavenPalette(
      {
        for (final token in ThemeToken.values)
          token: switch (token) {
            ThemeToken.background ||
            ThemeToken.surface ||
            ThemeToken.navigation => paper,
            _ => ink,
          },
      },
      true,
      settings.reducedMotion,
    );
  }
  final primary = rgb(base.primary);
  final secondary = rgb(base.secondary);
  final colors = {
    ThemeToken.primary: dark && base != ThemePreset.dark
        ? Color.lerp(primary, Colors.white, .44)!
        : primary,
    ThemeToken.secondary: dark && base != ThemePreset.dark
        ? Color.lerp(secondary, Colors.white, .47)!
        : secondary,
    ThemeToken.background: dark && base != ThemePreset.dark
        ? rgb(0x1e2422)
        : rgb(base.background),
    ThemeToken.surface: dark && base != ThemePreset.dark
        ? rgb(0x292f2c)
        : rgb(base.surface),
    ThemeToken.text: dark ? rgb(0xf3f0e9) : rgb(0x23271f),
    ThemeToken.navigation: dark ? rgb(0x303833) : rgb(0xf7f2e9),
    ThemeToken.progress: dark ? rgb(0xa4cfa5) : primary,
    ThemeToken.town: dark ? rgb(0x729a85) : rgb(0x83b9a5),
    ThemeToken.todo: rgb(0xc3b1e2),
    ThemeToken.routine: rgb(0xeaa6a6),
    ThemeToken.event: rgb(0x96c7d1),
    ThemeToken.my: rgb(0xead5a6),
    ThemeToken.more: rgb(0xbdafd9),
    if (mobile) ...{
      if (base == ThemePreset.classic) ...{
        ThemeToken.primary: PhoneStyle.accent,
        ThemeToken.progress: PhoneStyle.accent,
        ThemeToken.background: dark ? PhoneStyle.charcoal : PhoneStyle.paper,
        ThemeToken.surface: dark ? PhoneStyle.darkSurface : Colors.white,
        ThemeToken.navigation: dark ? PhoneStyle.darkSurface : Colors.white,
      },
      if (dark) ...{
        ThemeToken.background: PhoneStyle.charcoal,
        ThemeToken.surface: PhoneStyle.darkSurface,
        ThemeToken.navigation: PhoneStyle.darkSurface,
      },
    },
    if (settings.preset == ThemePreset.custom)
      for (final entry in settings.colors.entries) entry.key: rgb(entry.value),
  };
  if (settings.highContrast) {
    for (final token in [
      ThemeToken.surface,
      ThemeToken.background,
      ThemeToken.navigation,
    ]) {
      var color = colors[token]!;
      final luminance = color.computeLuminance();
      if (luminance > .1 && luminance < .3) {
        final pole = luminance < .179 ? Colors.black : Colors.white;
        while (color.computeLuminance() > .1 && color.computeLuminance() < .3) {
          color = Color.lerp(color, pole, .15)!;
        }
        colors[token] = color;
      }
    }
  }
  return HavenPalette(Map.unmodifiable(colors), false, settings.reducedMotion);
}

ThemeData havenTheme(
  Brightness brightness, [
  ThemeSettings settings = const ThemeSettings(),
  MobilePreferences? phone,
]) {
  final mobile = phone != null;
  final tokens = makePalette(brightness, settings, mobile: mobile);
  final mono = tokens.monochrome;
  final background = tokens[ThemeToken.background];
  final surface = tokens[ThemeToken.surface];
  final contrast = settings.highContrast ? 7.0 : 4.5;
  final ink = readableColor(
    tokens[ThemeToken.text],
    surface,
    minRatio: contrast,
  );
  final accent = readableColor(tokens[ThemeToken.primary], surface);
  final secondary = readableColor(tokens[ThemeToken.secondary], surface);
  final outline = readableColor(
    ink,
    surface,
    minRatio: settings.highContrast ? 7 : 3,
  );
  final soft = Color.lerp(ink, surface, settings.highContrast ? .38 : .78)!;
  final tinted = Color.lerp(surface, tokens[ThemeToken.primary], .18)!;
  final scheme = ColorScheme.fromSeed(
    seedColor: mono ? Colors.grey : accent,
    brightness: brightness,
    primary: accent,
    onPrimary: readableColor(background, accent),
    secondary: secondary,
    onSecondary: readableColor(background, secondary),
    primaryContainer: mono ? accent : tinted,
    onPrimaryContainer: mono ? background : readableColor(ink, tinted),
    secondaryContainer: surface,
    onSecondaryContainer: ink,
    tertiary: accent,
    onTertiary: readableColor(background, accent),
    tertiaryContainer: surface,
    onTertiaryContainer: ink,
    surface: surface,
    onSurface: ink,
    surfaceBright: surface,
    surfaceDim: surface,
    surfaceContainerLowest: surface,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: mono ? surface : Color.lerp(surface, accent, .09),
    onSurfaceVariant: readableColor(
      Color.lerp(ink, surface, .22)!,
      surface,
      minRatio: contrast,
    ),
    outline: outline,
    outlineVariant: soft,
    error: mono ? ink : readableColor(rgb(0xb44344), surface),
    onError: mono ? background : null,
    errorContainer: mono ? surface : null,
    onErrorContainer: mono ? ink : null,
    inverseSurface: ink,
    onInverseSurface: readableColor(background, ink),
    inversePrimary: readableColor(background, ink),
    surfaceTint: Colors.transparent,
    primaryFixed: accent,
    onPrimaryFixed: readableColor(background, accent),
    secondaryFixed: mono ? ink : null,
    secondaryFixedDim: mono ? ink : null,
    tertiaryFixed: mono ? ink : null,
    tertiaryFixedDim: mono ? ink : null,
    primaryFixedDim: mono ? ink : null,
    onPrimaryFixedVariant: mono ? background : null,
    onSecondaryFixed: mono ? background : null,
    onSecondaryFixedVariant: mono ? background : null,
    onTertiaryFixed: mono ? background : null,
    onTertiaryFixedVariant: mono ? background : null,
  );
  final canvasInk = readableColor(
    tokens[ThemeToken.text],
    background,
    minRatio: contrast,
  );
  final base = ThemeData(
    colorScheme: scheme,
    extensions: [
      tokens,
      if (phone != null) PhoneStyle(phone, settings.highContrast),
    ],
    visualDensity: mobile ? VisualDensity.standard : null,
    materialTapTargetSize: mobile ? MaterialTapTargetSize.padded : null,
    appBarTheme: mobile
        ? AppBarTheme(
            backgroundColor: background,
            foregroundColor: canvasInk,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
          )
        : null,
    fontFamily: 'DM Sans',
    scaffoldBackgroundColor: background,
    dividerColor: soft,
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: readableColor(tokens[ThemeToken.progress], surface, minRatio: 3),
      linearTrackColor: soft,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: mobile ? tokens[ThemeToken.primary] : null,
        foregroundColor: mobile
            ? readableColor(ink, tokens[ThemeToken.primary], minRatio: contrast)
            : null,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mobile ? PhoneStyle.radius : 14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mobile ? PhoneStyle.radius : 14),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: canvasInk,
      displayColor: canvasInk,
    ),
  );
}

Color panelColor(BuildContext context) => Theme.of(context).colorScheme.surface;

TextStyle muted(BuildContext context, {double size = 13}) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.w400);

TextStyle displayStyle(BuildContext context, {double size = 34}) => TextStyle(
  fontFamily: phoneStyle(context) == null ? 'Haven Serif' : 'DM Sans',
  fontWeight: phoneStyle(context) == null ? FontWeight.w600 : FontWeight.w700,
  height: 1.1,
  fontSize: size,
  letterSpacing: -.75,
  color:
      DefaultTextStyle.of(context).style.color ??
      Theme.of(context).colorScheme.onSurface,
);

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final mobile = phoneStyle(context) != null;
    final mono = palette(context).monochrome;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(mobile ? PhoneStyle.radius : 22),
      side: mobile && !mono && !(phoneStyle(context)?.highContrast ?? false)
          ? BorderSide.none
          : BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: palette(context).monochrome
            ? const []
            : [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow
                      .withValues(alpha: mobile ? .045 : .07),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Material(
        color: panelColor(context),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro(this.title, this.description, {super.key, this.action});
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: displayStyle(context, size: 36)),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(description, style: muted(context, size: 14)),
        ],
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(
    this.title,
    this.description, {
    super.key,
    required this.icon,
  });
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Panel(
    child: SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: muted(context),
            ),
          ],
        ),
      ),
    ),
  );
}

String formattedDate(BuildContext context, String day) =>
    MaterialLocalizations.of(context).formatMediumDate(dateFromKey(day));

String euro(int cents) {
  final absolute = cents.abs();
  final digits = (absolute ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '${cents < 0 ? '−' : ''}€$digits.${(absolute % 100).toString().padLeft(2, '0')}';
}

IconData categoryIcon(TaskCategory category) => switch (category) {
  TaskCategory.home => Icons.home_outlined,
  TaskCategory.school => Icons.school_outlined,
  TaskCategory.personal => Icons.favorite_border_rounded,
  TaskCategory.work => Icons.work_outline_rounded,
};

void showNotice(BuildContext context, String message, {IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: icon == null
            ? Text(message)
            : Row(
                children: [
                  Icon(
                    icon,
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(message)),
                ],
              ),
      ),
    );
}
