import 'package:flutter/material.dart';

class LumoraLogo extends StatelessWidget {
  const LumoraLogo({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset('assets/branding/logo.png',
            width: size, height: size, filterQuality: FilterQuality.medium),
      );
}
