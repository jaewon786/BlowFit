import 'package:flutter/foundation.dart';

@immutable
class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;

  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });
}
