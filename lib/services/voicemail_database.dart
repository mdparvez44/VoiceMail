import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class VoicemailDatabase {
  VoicemailDatabase._();

  static final VoicemailDatabase instance = VoicemailDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = p.join(await getDatabasesPath(), 'personal_butler.db');

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE voicemails (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            callerName TEXT NOT NULL,
            phoneNumber TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            durationSeconds INTEGER NOT NULL DEFAULT 0,
            recordingPath TEXT,
            isRead INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );

    return _database!;
  }

  Future<int> addVoicemail({
    required String callerName,
    required String phoneNumber,
    int durationSeconds = 0,
    String? recordingPath,
  }) async {
    final db = await database;

    return db.insert('voicemails', {
      'callerName': callerName,
      'phoneNumber': phoneNumber,
      'createdAt': DateTime.now().toIso8601String(),
      'durationSeconds': durationSeconds,
      'recordingPath': recordingPath,
      'isRead': 0,
    });
  }

  Future<List<Map<String, Object?>>> getVoicemails() async {
    final db = await database;

    return db.query('voicemails', orderBy: 'createdAt DESC');
  }

  Future<void> markAsRead(int id) async {
    final db = await database;

    await db.update(
      'voicemails',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteVoicemail(int id) async {
    final db = await database;

    await db.delete('voicemails', where: 'id = ?', whereArgs: [id]);
  }
}
