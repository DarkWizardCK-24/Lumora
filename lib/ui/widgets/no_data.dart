import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';

class NoData extends StatelessWidget {
  const NoData({super.key});
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: Text('No data in this range yet.', style: TextStyle(color: Palette.muted))));
}
