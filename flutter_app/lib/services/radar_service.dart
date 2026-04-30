// Radar service — BLE sensor detection.
// MVP: mocks a 120 cm reading when a radar/HC-SR04 BLE device is found.
// Real BLE GATT parsing is hardware-specific and left as an extension point.

class RadarService {
  static bool _hasRadar = false;

  static bool get hasRadar => _hasRadar;

  /// Call on splash to check for BLE radar sensor.
  static Future<bool> detectSensor() async {
    // Bluetooth scanning is disabled in this build to keep web/emulator working.
    // To enable on physical device: uncomment the flutter_blue_plus scan below
    // and add BLUETOOTH permissions in AndroidManifest / Info.plist.
    _hasRadar = false;
    return _hasRadar;
  }

  /// Returns mock readings for MVP. Replace with real BLE reads when hardware is available.
  static Future<List<Map<String, dynamic>>?> getReadings() async {
    if (!_hasRadar) return null;
    return [
      {'distance_cm': 120.0, 'angle_deg': 0.0},
    ];
  }
}
