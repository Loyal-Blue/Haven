enum DashboardCard {
  town('Town', 0xffd774),
  tasks('Tasks', 0xf5d5cb),
  money('Finances', 0xe6dccb),
  hobbies('Hobbies', 0xdce8cb),
  assistant('Haven AI', 0xe5dcf8),
  calendar('Calendar', 0xdce9eb);

  const DashboardCard(this.label, this.color);
  final String label;
  final int color;
}

enum MobileMotion {
  still('Off', 0),
  gentle('Gentle', .65),
  full('Full', 1);

  const MobileMotion(this.label, this.factor);
  final String label;
  final double factor;
}

class MobilePreferences {
  const MobilePreferences({
    this.name = '',
    this.order = DashboardCard.values,
    this.colors = const {},
    this.motion = MobileMotion.gentle,
  });
  final String name;
  final List<DashboardCard> order;
  final Map<DashboardCard, int> colors;
  final MobileMotion motion;

  MobilePreferences copyWith({
    String? name,
    List<DashboardCard>? order,
    Map<DashboardCard, int>? colors,
    MobileMotion? motion,
  }) => MobilePreferences(
    name: name ?? this.name,
    order: order == null ? this.order : List.unmodifiable(order),
    colors: colors == null ? this.colors : Map.unmodifiable(colors),
    motion: motion ?? this.motion,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'order': order.map((card) => card.name).toList(),
    'colors': {for (final entry in colors.entries) entry.key.name: entry.value},
    'motion': motion.name,
  };

  factory MobilePreferences.fromJson(Object? value) {
    if (value is! Map) return const MobilePreferences();
    final order = value['order'];
    final colors = value['colors'];
    final byName = {for (final card in DashboardCard.values) card.name: card};
    final name = value['name'];
    return MobilePreferences(
      name: name is String ? name.trim() : '',
      order: List.unmodifiable({
        if (order is List)
          for (final item in order) ?byName[item],
        ...DashboardCard.values,
      }),
      colors: Map.unmodifiable({
        if (colors is Map)
          for (final card in DashboardCard.values)
            if (colors[card.name] case final int color
                when color >= 0 && color <= 0xffffff)
              card: color,
      }),
      motion:
          MobileMotion.values
              .where((motion) => motion.name == value['motion'])
              .firstOrNull ??
          MobileMotion.gentle,
    );
  }
}
