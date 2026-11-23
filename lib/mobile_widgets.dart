import 'package:material_ui/material_ui.dart';

import 'design.dart';
import 'domain.dart';
import 'mobile_preferences.dart';
import 'theme_settings.dart';

class PhoneWeek extends StatefulWidget {
  const PhoneWeek({
    super.key,
    required this.week,
    required this.selected,
    required this.today,
    required this.onSelect,
  });
  final DateTime week;
  final String selected, today;
  final ValueChanged<String> onSelect;

  @override
  State<PhoneWeek> createState() => _PhoneWeekState();
}

class _PhoneWeekState extends State<PhoneWeek> {
  final selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    revealSelection();
  }

  @override
  void didUpdateWidget(PhoneWeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) revealSelection();
  }

  void revealSelection() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final target = selectedKey.currentContext;
    final scroll = target == null
        ? null
        : Scrollable.maybeOf(target, axis: Axis.horizontal);
    if (target != null &&
        scroll != null &&
        scroll.position.maxScrollExtent > 0) {
      scroll.position.ensureVisible(
        target.findRenderObject()!,
        alignment: .5,
        duration: phoneMotion(context, 170),
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = palette(context);
    final accent = colors[ThemeToken.primary];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < PhoneStyle.touch * 7
            ? PhoneStyle.touch
            : constraints.maxWidth / 7;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < 7; index++)
                Builder(
                  builder: (context) {
                    final date = calendarDay(widget.week, index);
                    final day = dayKey(date);
                    final selected = widget.selected == day;
                    final today = widget.today == day;
                    final background = selected
                        ? accent
                        : theme.colorScheme.surface;
                    final foreground = phoneInk(context, background);
                    final longDay = MaterialLocalizations.of(context)
                        .formatFullDate(date);
                    return SizedBox(
                      key: selected ? selectedKey : ValueKey(day),
                      width: width,
                      child: Semantics(
                        label: longDay,
                        selected: selected,
                        button: true,
                        onTap: () => widget.onSelect(day),
                        child: ExcludeSemantics(
                          child: Column(
                            children: [
                              Text(
                                const [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ][index],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: today
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Material(
                                color: background,
                                shape: CircleBorder(
                                  side:
                                      !selected && (today || colors.monochrome)
                                      ? BorderSide(
                                          color:
                                              theme.colorScheme.outlineVariant,
                                        )
                                      : BorderSide.none,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => widget.onSelect(day),
                                  child: SizedBox.square(
                                    dimension: PhoneStyle.touch,
                                    child: Center(
                                      child: Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: foreground,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class PhoneProgress extends StatelessWidget {
  const PhoneProgress({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });
  final double value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final duration = phoneMotion(context, 260);
    final progress = value.clamp(0.0, 1.0);
    Widget indicator(double amount) => LinearProgressIndicator(
      value: amount,
      minHeight: 8,
      borderRadius: BorderRadius.circular(12),
      color: color,
      semanticsLabel: label,
      semanticsValue: '${(progress * 100).round()}%',
    );
    if (duration == Duration.zero) return indicator(progress);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, amount, _) => indicator(amount),
    );
  }
}

typedef PhoneMetric = ({String label, double fraction, DashboardCard card});

class PhonePills extends StatelessWidget {
  const PhonePills({super.key, required this.metrics});
  final List<PhoneMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final mono = palette(context).monochrome;
    final track = Color.lerp(scheme.surface, scheme.onSurface, .075)!;
    final duration = phoneMotion(context, 360);
    const trackHeight = 132.0;
    final labelHeight = MediaQuery.textScalerOf(context).scale(13) * 1.35;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final largeText = MediaQuery.textScalerOf(context).scale(13) > 17;
        final columns = (largeText || constraints.maxWidth < 260 ? 2 : 4).clamp(
          1,
          metrics.length,
        );
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: PhoneStyle.gap,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: Semantics(
                  label:
                      '${metric.label}, ${(metric.fraction * 100).round()} percent',
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        SizedBox(
                          height: trackHeight,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              PhoneStyle.radius,
                            ),
                            child: ColoredBox(
                              color: track,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: metric.fraction.clamp(0.0, 1.0),
                                ),
                                duration: duration,
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  final fill = mono
                                      ? scheme.onSurface
                                      : phoneCardColor(context, metric.card);
                                  final fillHeight = value * trackHeight;
                                  final inFill = fillHeight >= labelHeight + 12;
                                  return Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      FractionallySizedBox(
                                        widthFactor: 1,
                                        heightFactor: value,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: fill,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: inFill || value == 0
                                            ? 8
                                            : fillHeight + 5,
                                        left: 4,
                                        right: 4,
                                        child: Text(
                                          '${(metric.fraction * 100).round()}%',
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: phoneInk(
                                              context,
                                              inFill ? fill : track,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          metric.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class PhoneCheck extends StatelessWidget {
  const PhoneCheck({super.key, required this.done, required this.category});
  final bool done;
  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    final tokens = palette(context);
    final background = done ? tokens[ThemeToken.primary] : null;
    return AnimatedScale(
      scale: done ? 1.09 : 1,
      duration: phoneMotion(context, 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        width: 26,
        height: 26,
        duration: phoneMotion(context, 175),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
          border: background == null
              ? Border.all(color: Theme.of(context).colorScheme.outline)
              : null,
        ),
        child: Icon(
          done ? Icons.check_rounded : categoryIcon(category),
          size: 15,
          color: background == null
              ? Theme.of(context).colorScheme.onSurface
              : phoneInk(context, background),
        ),
      ),
    );
  }
}
