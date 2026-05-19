import 'package:flutter/widgets.dart';

enum OrgDensityLevel { compact, comfortable }

class OrgDensity extends InheritedWidget {
  const OrgDensity({super.key, required this.level, required super.child});

  final OrgDensityLevel level;

  static OrgDensityLevel of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<OrgDensity>();
    return widget?.level ?? OrgDensityLevel.comfortable;
  }

  @override
  bool updateShouldNotify(OrgDensity oldWidget) => oldWidget.level != level;
}

double densitySelect(
  BuildContext context, {
  required double compact,
  required double comfortable,
}) {
  return OrgDensity.of(context) == OrgDensityLevel.compact
      ? compact
      : comfortable;
}
