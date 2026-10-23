import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:personal_buttler/services/voicemail_database.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    // Initialize FFI for sqflite on the test VM.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Ensure a clean database file.
    final dbPath = p.join(await getDatabasesPath(), 'personal_butler.db');
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  tearDownAll(() async {
    // Clean up the test database file after all tests.
    final dbPath = p.join(await getDatabasesPath(), 'personal_butler.db');
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  test('Insert and retrieve voicemail', () async {
    final id = await VoicemailDatabase.instance.addVoicemail(
      callerName: 'Alice',
      phoneNumber: '+1234567890',
      durationSeconds: 42,
      recordingPath: '/tmp/dummy.wav',
    );
    expect(id, isA<int>());

    final messages = await VoicemailDatabase.instance.getVoicemails();
    expect(messages, isNotEmpty);
    final first = messages.first;
    expect(first['callerName'], 'Alice');
    expect(first['phoneNumber'], '+1234567890');
    expect(first['durationSeconds'], 42);
    expect(first['recordingPath'], '/tmp/dummy.wav');
  });
}
