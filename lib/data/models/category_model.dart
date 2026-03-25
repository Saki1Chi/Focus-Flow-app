import 'dart:convert';
import 'package:flutter/material.dart';

class Category {
  final int id;
  final String name;
  final String color; // hex, e.g. "#4A90E2"
  final String icon;

  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  Color get colorValue {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        name: json['name'] as String,
        color: json['color'] as String? ?? '#4A90E2',
        icon: json['icon'] as String? ?? 'label',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'icon': icon,
      };

  String toJsonString() => jsonEncode(toJson());
}
