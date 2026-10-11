import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 88});
  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.home_work_rounded,
        size: size, color: Theme.of(context).colorScheme.primary);
    return FutureBuilder<AssetManifest>(
      future: AssetManifest.loadFromAssetBundle(DefaultAssetBundle.of(context)),
      builder: (context, snapshot) =>
          snapshot.data?.listAssets().contains('assets/images/logo.png') == true
              ? Image.asset('assets/images/logo.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  semanticLabel: 'Campus Home',
                  errorBuilder: (_, __, ___) => fallback)
              : fallback,
    );
  }
}
