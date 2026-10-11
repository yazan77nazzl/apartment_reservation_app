import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 88});
  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Campus Home',
        errorBuilder: (_, __, ___) => Icon(Icons.home_work_rounded,
            size: size, color: Theme.of(context).colorScheme.primary),
      );
}
