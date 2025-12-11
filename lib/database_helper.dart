import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart'; 
import 'word_model.dart';

List<dynamic> _parseJson(String jsonString) {
  return json.decode(jsonString);
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  bool _isImporting = false; 

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lemon_words_v2.db'); // 升级数据库名
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE words (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word TEXT, phonetic TEXT, definition TEXT, bookName TEXT, status INTEGER DEFAULT 0
    )''');
    await db.execute('CREATE INDEX idx_bookName ON words(bookName)');
    await db.execute('CREATE INDEX idx_status ON words(status)'); 
    
    // ✅ 新增：学习日志表
    await db.execute('CREATE TABLE study_logs (date TEXT PRIMARY KEY, count INTEGER DEFAULT 0)');
    // ✅ 新增：进度表
    await db.execute('CREATE TABLE study_progress (bookName TEXT PRIMARY KEY, currentGroup INTEGER DEFAULT 0, lastReviewTime TEXT)');
  }

  Future<void> importJsonData(String jsonFileName, String bookName) async {
    if (_isImporting) return;
    _isImporting = true;
    final db = await instance.database;
    final check = await db.rawQuery('SELECT count(*) as count FROM words WHERE bookName = ? LIMIT 1', [bookName]);
    if ((Sqflite.firstIntValue(check) ?? 0) > 0) {
      _isImporting = false; return; 
    }
    try {
      String jsonString = await rootBundle.loadString('assets/data/$jsonFileName');
      final List<dynamic> jsonList = await compute(_parseJson, jsonString);
      const int batchSize = 500; 
      for (var i = 0; i < jsonList.length; i += batchSize) {
        var end = (i + batchSize < jsonList.length) ? i + batchSize : jsonList.length;
        var batchList = jsonList.sublist(i, end);
        await db.transaction((txn) async {
          var batch = txn.batch();
          for (var item in batchList) {
             Word w = Word.fromJson(item, bookName);
             batch.insert('words', w.toMap());
          }
          await batch.commit(noResult: true);
        });
        await Future.delayed(const Duration(milliseconds: 1));
      }
      await saveStudyProgress(StudyProgress(bookName: bookName, currentGroup: 0));
    } catch (e) {
      debugPrint("❌ Error: $e");
    } finally {
      _isImporting = false;
    }
  }

  // --- ✅ 补全所有缺失的方法 ---

  Future<void> markWordAsLearned(int wordId) async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now()); 
    await db.transaction((txn) async {
      await txn.update('words', {'status': 1}, where: 'id = ?', whereArgs: [wordId]);
      await txn.rawInsert('INSERT INTO study_logs (date, count) VALUES (?, 1) ON CONFLICT(date) DO UPDATE SET count = count + 1', [today]);
    });
  }

  Future<int> getTodayCount() async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await db.query('study_logs', where: 'date = ?', whereArgs: [today]);
    if (result.isNotEmpty) return result.first['count'] as int;
    return 0;
  }

  Future<Map<int, int>> getMonthlyData(int year, int month) async {
    final db = await instance.database;
    String prefix = DateFormat('yyyy-MM-').format(DateTime(year, month));
    final result = await db.query('study_logs', where: "date LIKE ?", whereArgs: ['$prefix%']);
    Map<int, int> stats = {};
    for (var row in result) {
      String date = row['date'] as String; 
      int day = int.parse(date.split('-')[2]); 
      stats[day] = row['count'] as int;
    }
    return stats;
  }

  Future<StudyProgress> getStudyProgress(String bookName) async {
    final db = await instance.database;
    final res = await db.query('study_progress', where: 'bookName = ?', whereArgs: [bookName]);
    if (res.isNotEmpty) return StudyProgress.fromMap(res.first);
    return StudyProgress(bookName: bookName, currentGroup: 0);
  }

  Future<void> saveStudyProgress(StudyProgress p) async {
    final db = await instance.database;
    await db.insert('study_progress', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getTotalWords(String bookName) async {
    final db = await instance.database;
    var res = await db.rawQuery('SELECT count(*) FROM words WHERE bookName = ?', [bookName]);
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<List<Word>> getUnlearnedWords(String bookName, {int limit = 20}) async {
    final db = await instance.database;
    final result = await db.query('words', where: 'bookName = ? AND status = 0', whereArgs: [bookName], orderBy: 'id ASC', limit: limit);
    return result.map((json) => Word.fromMap(json)).toList();
  }
  
  // 兼容旧方法
  Future<List<Word>> getWordsByBook(String bookName) async {
    return getUnlearnedWords(bookName);
  }

  Future<void> devUpdateStat(String date, int count) async {
    final db = await instance.database;
    await db.insert('study_logs', {'date': date, 'count': count}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}