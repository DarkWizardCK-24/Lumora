import 'package:flutter/material.dart';
import '../../core/models/activity.dart';

class CalendarItem {
  CalendarItem(this.when, this.title, this.color, this.icon, {this.activity, this.sub = ''});
  final DateTime when;
  final String title, sub;
  final Color color;
  final IconData icon;
  final Activity? activity;
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
