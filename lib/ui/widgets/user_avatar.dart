import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';

/// Profile picture, or the user's initial when none is set.
class UserAvatar extends StatelessWidget {
  const UserAvatar(this.user, {super.key, this.radius = 20});
  final LocalUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final a = user.avatar;
    return CircleAvatar(
      radius: radius,
      backgroundImage: a == null ? null : MemoryImage(a),
      child: a == null
          ? Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.8))
          : null,
    );
  }
}
