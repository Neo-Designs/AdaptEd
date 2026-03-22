import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/dynamic_theme.dart';

class AdaptedCard extends StatelessWidget {
  final Widget child;

  const AdaptedCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dt = context.watch<DynamicTheme>();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: dt.glassDecoration,
      padding: EdgeInsets.all(dt.interactivePadding),
      child: child,
    );
  }
}
