import 'package:adapted/core/theme/dynamic_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdaptedButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AdaptedButton(
      {super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final dt = context.read<DynamicTheme>();

    return ElevatedButton(
      onPressed: onPressed,
      style: dt.traits.isDyspraxic
          ? dt.primaryButtonStyle.copyWith(
              minimumSize:
                  const WidgetStatePropertyAll(Size(double.infinity, 60)),
            )
          : null,
      child: Text(label),
    );
  }
}
