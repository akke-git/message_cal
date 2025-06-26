import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('message_calendar.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 2, // 버전 업그레이드
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
CREATE TABLE pending_events (
  id $idType,
  shared_text $textType,
  status $textType,
  created_at $textType,
  title $textTypeNullable,
  event_date $textTypeNullable,
  event_time $textTypeNullable,
  category $textTypeNullable,
  calendar_event_id $textTypeNullable
)''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 버전 1에서 2로 업그레이드: 새 컬럼들 추가
      await db.execute('ALTER TABLE pending_events ADD COLUMN title TEXT');
      await db.execute('ALTER TABLE pending_events ADD COLUMN event_date TEXT');
      await db.execute('ALTER TABLE pending_events ADD COLUMN event_time TEXT');
      await db.execute('ALTER TABLE pending_events ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE pending_events ADD COLUMN calendar_event_id TEXT');
    }
  }

  Future<int> createPendingEvent(String sharedText) async {
    final db = await instance.database;
    final data = {
      'shared_text': sharedText,
      'status': 'pending', // pending, processing, completed, failed
      'created_at': DateTime.now().toIso8601String(),
    };
    return await db.insert('pending_events', data);
  }

  Future<List<Map<String, dynamic>>> getPendingEvents() async {
    final db = await instance.database;
    return await db.query('pending_events', where: 'status = ?', whereArgs: ['pending']);
  }

  Future<int> updateEventStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update('pending_events', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateEventWithDetails(
    int id, 
    String status,
    String title,
    String eventDate,
    String? eventTime,
    String category,
  ) async {
    final db = await instance.database;
    return await db.update('pending_events', {
      'status': status,
      'title': title,
      'event_date': eventDate,
      'event_time': eventTime,
      'category': category,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateEventWithDetailsAndId(
    int id, 
    String status,
    String title,
    String eventDate,
    String? eventTime,
    String category,
    String calendarEventId,
  ) async {
    final db = await instance.database;
    return await db.update('pending_events', {
      'status': status,
      'title': title,
      'event_date': eventDate,
      'event_time': eventTime,
      'category': category,
      'calendar_event_id': calendarEventId,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteEvent(int id) async {
    final db = await instance.database;
    return await db.delete('pending_events', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
