import 'dart:convert';

import 'package:flutter/material.dart';

/// A client's colours and logo, from `/v1/mobile/me` → `company.branding`. Bad values fall back to defaults.
@immutable
class Branding {
  const Branding({required this.primary, required this.accent, this.logoUrl});

  static const defaults = Branding(primary: Color(0xFF4F46E5), accent: Color(0xFF0EA5E9));

  final Color primary;
  final Color accent;

  /// https link to the company logo; null shows the company initials.
  final String? logoUrl;

  static Branding fromJson(Object? json) {
    if (json is! Map) return defaults;
    return Branding(
      primary: _color(json['primaryColor']) ?? defaults.primary,
      accent: _color(json['accentColor']) ?? defaults.accent,
      logoUrl: _logo(json['logoUrl']),
    );
  }

  /// Reads what [encode] stored; anything unreadable gives the defaults.
  static Branding decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      return fromJson(jsonDecode(raw));
    } on FormatException {
      return defaults;
    }
  }

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() => {'primaryColor': hex(primary), 'accentColor': hex(accent), 'logoUrl': logoUrl};

  static String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Color? _color(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(value.trim());
    return match == null ? null : Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }

  static String? _logo(Object? value) {
    if (value is! String) return null;
    final url = value.trim();
    return RegExp(r'^https://[^\s"<>]+$').hasMatch(url) ? url : null;
  }

  @override
  bool operator ==(Object other) =>
      other is Branding && other.primary.toARGB32() == primary.toARGB32() && other.accent.toARGB32() == accent.toARGB32() && other.logoUrl == logoUrl;

  @override
  int get hashCode => Object.hash(primary.toARGB32(), accent.toARGB32(), logoUrl);
}
