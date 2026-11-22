import 'package:material_ui/material_ui.dart';

import 'domain.dart';

const graphite = Color(0xff292d2c);
const railText = Color(0xffedf0ee);
const silverMint = Color(0xffdde6e0);

ThemeData havenTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff76837d),
    brightness: brightness,
    primary: dark ? const Color(0xffc9d8ce) : graphite,
    onPrimary: dark ? const Color(0xff202924) : const Color(0xfff9fbfa),
    primaryContainer: dark ? const Color(0xff485650) : silverMint,
    onPrimaryContainer: dark
        ? const Color(0xffeff4f0)
        : const Color(0xff28332f),
    surface: dark ? const Color(0xff252827) : const Color(0xffe0e3e1),
    onSurface: dark ? const Color(0xffedf0ed) : const Color(0xff222624),
    onSurfaceVariant: dark ? const Color(0xffbbc3bd) : const Color(0xff4b5650),
    outline: dark ? const Color(0xff829089) : const Color(0xff76817b),
    outlineVariant: dark ? const Color(0xff4a504d) : const Color(0xffcbd1cd),
    error: dark ? const Color(0xfff1b7ad) : const Color(0xff943e39),
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'DM Sans',
    scaffoldBackgroundColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xff2f3431) : const Color(0xffeff1ef),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

Color panelColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff303532)
    : const Color(0xfff1f3f1);

TextStyle muted(BuildContext context, {double size = 13}) => TextStyle(
  color: Theme.of(context).colorScheme.onSurfaceVariant,
  fontSize: size,
);

TextStyle displayStyle(BuildContext context, {double size = 34}) => TextStyle(
  fontWeight: FontWeight.w600,
  height: 1.1,
  fontSize: size,
  letterSpacing: -.75,
  color: Theme.of(context).colorScheme.onSurface,
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: const [
          BoxShadow(
            color: Color(0x130e1511),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        color: panelColor(context),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
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

void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
