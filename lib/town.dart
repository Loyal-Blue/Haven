import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';
import 'domain.dart';
import 'theme_settings.dart';

const worldWidth = 320.0;
const worldHeight = 304.0;

Offset _project(double x, double y) =>
    Offset(155 + 14 * (x - 5) - 14 * (y - 4), 165 + 5 * (x - 5) + 16 * (y - 4));

const _centerTerrain = (name: 'Town center', image: 'terrain');
const _districtTerrain = [
  (name: 'Upper meadows', image: 'terrain-meadows'),
  (name: 'Pinewood', image: 'terrain-pinewood'),
  (name: 'Highlands', image: 'terrain-highlands'),
];

class DistrictNavigation extends StatelessWidget {
  const DistrictNavigation({
    super.key,
    required this.district,
    required this.count,
    required this.nextMonday,
    required this.onSelect,
  });

  final int district;
  final int count;
  final String? nextMonday;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        if (count > 1)
          IconButton(
            tooltip: 'Previous district',
            onPressed: district > 0 ? () => onSelect(district - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          )
        else ...[
          const SizedBox(width: 5),
          const Icon(Icons.map_outlined, size: 19),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'District ${district + 1} of $count',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (nextMonday case final next?)
                  Text(
                    'Next construction · ${formattedDate(context, next)}',
                    style: muted(context, size: 12),
                  ),
              ],
            ),
          ),
        ),
        if (count > 1)
          IconButton(
            tooltip: 'Next district',
            onPressed: district + 1 < count
                ? () => onSelect(district + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
      ],
    ),
  );
}

class TownMap extends StatefulWidget {
  const TownMap({
    super.key,
    required this.buildings,
    required this.title,
    required this.level,
    this.wide = false,
    this.district = 0,
  });

  final List<PlacedBuilding> buildings;
  final String title;
  final int level;
  final bool wide;
  final int district;

  @override
  State<TownMap> createState() => _TownMapState();
}

class _TownMapState extends State<TownMap> {
  final camera = TransformationController();

  @override
  void dispose() {
    camera.dispose();
    super.dispose();
  }

  void zoom(double factor, Size viewport) {
    final origin = Offset(viewport.width / 2, viewport.height / 2);
    final scene = camera.toScene(origin);
    final scale = (camera.value.getMaxScaleOnAxis() * factor).clamp(1.0, 3.0);
    final x = (origin.dx - scene.dx * scale).clamp(
      viewport.width * (1 - scale),
      0.0,
    );
    final y = (origin.dy - scene.dy * scale).clamp(
      viewport.height * (1 - scale),
      0.0,
    );
    camera.value = Matrix4.identity()
      ..scaleByDouble(scale, scale, scale, 1)
      ..setTranslationRaw(x, y, 0);
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: widget.wide ? 1.58 : 1.1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.biggest;
            final scale = math.max(
              viewport.width / worldWidth,
              viewport.height / worldHeight,
            );
            final offset = Offset(
              (viewport.width - worldWidth * scale) / 2,
              (viewport.height - worldHeight * scale) / 2,
            );
            final terrain = widget.district == 0
                ? _centerTerrain
                : _districtTerrain[(widget.district - 1) %
                      _districtTerrain.length];
            Offset screenPosition(Plot plot) =>
                offset + _project(plot.x.toDouble(), plot.y.toDouble()) * scale;

            final objects = widget.buildings.toList()
              ..sort(
                (a, b) =>
                    screenPosition(a.plot).dy
                        .compareTo(screenPosition(b.plot).dy),
              );
            Widget sprite(PlacedBuilding building) {
              final origin = screenPosition(building.plot);
              return Positioned(
                left: origin.dx - 12 * scale,
                top: origin.dy - 18.75 * scale,
                width: 24 * scale,
                height: 24 * scale,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/world/${building.building.name}.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                    excludeFromSemantics: true,
                  ),
                ),
              );
            }

            final colors = palette(context);
            final ink = colors[ThemeToken.text];
            final surface = colors[ThemeToken.surface];
            final titleInk = readableColor(ink, surface);
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: colors[ThemeToken.town],
                  child: ColorFiltered(
                    colorFilter: colors.monochrome
                        ? const ColorFilter.matrix([
                            .2126,
                            .7152,
                            .0722,
                            0,
                            0,
                            .2126,
                            .7152,
                            .0722,
                            0,
                            0,
                            .2126,
                            .7152,
                            .0722,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ])
                        : ColorFilter.mode(
                            colors[ThemeToken.town].withValues(alpha: .16),
                            BlendMode.srcATop,
                          ),
                    child: InteractiveViewer(
                      transformationController: camera,
                      maxScale: 3,
                      trackpadScrollCausesScale: true,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned(
                            left: offset.dx,
                            top: offset.dy,
                            width: worldWidth * scale,
                            height: worldHeight * scale,
                            child: Image.asset(
                              'assets/world/${terrain.image}.png',
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.none,
                              excludeFromSemantics: true,
                            ),
                          ),
                          for (final building in objects) sprite(building),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 11,
                  top: 10,
                  right: 53,
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.monochrome
                              ? surface
                              : surface.withValues(alpha: .96),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: displayStyle(
                                  context,
                                  size: widget.wide ? 31 : 24,
                                ).copyWith(color: titleInk),
                              ),
                              Text(
                                '${terrain.name} · Level ${widget.level}',
                                style: TextStyle(
                                  color: titleInk,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Column(
                    children: [
                      _MapButton(
                        Icons.add,
                        'Zoom in',
                        () => zoom(1.32, viewport),
                      ),
                      const SizedBox(height: 3),
                      _MapButton(
                        Icons.remove,
                        'Zoom out',
                        () => zoom(1 / 1.32, viewport),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _MapButton extends StatelessWidget {
  const _MapButton(this.icon, this.label, this.onPressed);
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: panelColor(context),
    borderRadius: BorderRadius.circular(11),
    child: IconButton(
      onPressed: onPressed,
      tooltip: label,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      color: Theme.of(context).colorScheme.onSurface,
      icon: Icon(icon, size: 20),
    ),
  );
}
