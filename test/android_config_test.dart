// Guards the Android network settings: plain HTTP is allowed only for the
// local development API, never app-wide.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final config = File('android/app/src/main/res/xml/network_security_config.xml');

  test('the app does not allow plain HTTP everywhere', () {
    expect(manifest, isNot(contains('usesCleartextTraffic')));
    expect(manifest, contains('android:networkSecurityConfig="@xml/network_security_config"'));
  });

  test('plain HTTP is limited to the local API hosts', () {
    final xml = config.readAsStringSync();
    expect(xml, contains('<base-config cleartextTrafficPermitted="false" />'));
    final hosts = RegExp(r'<domain[^>]*>([^<]+)</domain>').allMatches(xml).map((m) => m[1]);
    expect(hosts.toSet(), {'10.0.2.2', 'localhost', '127.0.0.1'});
  });
}
