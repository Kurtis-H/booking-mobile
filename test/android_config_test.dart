// Guards the Android security settings (mobile-security-lab MS-02, MS-04):
// release builds allow no plain HTTP at all; debug and profile builds allow it
// only to the local development API; app data is never backed up.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> cleartextHosts(String xml) =>
    RegExp(r'<domain[^>]*>([^<]+)</domain>').allMatches(xml).map((m) => m[1]!).toSet();

String networkConfig(String sourceSet) =>
    File('android/app/src/$sourceSet/res/xml/network_security_config.xml').readAsStringSync();

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('the app does not allow plain HTTP everywhere', () {
    expect(manifest, isNot(contains('usesCleartextTraffic')));
    expect(manifest, contains('android:networkSecurityConfig="@xml/network_security_config"'));
  });

  test('release builds allow no plain HTTP at all', () {
    final xml = networkConfig('main');
    expect(xml, contains('<base-config cleartextTrafficPermitted="false" />'));
    expect(xml, isNot(contains('cleartextTrafficPermitted="true"')));
    expect(cleartextHosts(xml), isEmpty);
  });

  for (final sourceSet in ['debug', 'profile']) {
    test('$sourceSet builds allow plain HTTP only to the local API hosts', () {
      final xml = networkConfig(sourceSet);
      expect(xml, contains('<base-config cleartextTrafficPermitted="false" />'));
      expect(cleartextHosts(xml), {'10.0.2.2', 'localhost', '127.0.0.1'});
    });
  }

  test('app data is not backed up or transferred', () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp('<$section>(.*?)</$section>', dotAll: true).firstMatch(rules)![1]!;
      expect(body, contains('<exclude domain="root" />'), reason: section);
    }
  });
}
