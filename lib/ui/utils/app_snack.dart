import 'package:flutter/material.dart';
import '../../core/colors/app_colors.dart';

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Palette.danger : null,
    ));
}
