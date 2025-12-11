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

  static final List<int> _reviewIntervals = [1, 2, 4, 7, 15, 30];

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // ✅ 升级数据库版本 v4 (触发新建表)
    _database = await _initDB('lemon_words_v4.db'); 
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // ✅ 增加 isMistake 字段
    await db.execute('''
    CREATE TABLE words (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word TEXT, 
      phonetic TEXT, 
      definition TEXT, 
      bookName TEXT, 
      status INTEGER DEFAULT 0,
      reviewStage INTEGER DEFAULT 0,
      nextReviewTime TEXT,
      isMistake INTEGER DEFAULT 0
    )''');
    await db.execute('CREATE INDEX idx_bookName ON words(bookName)');
    await db.execute('CREATE INDEX idx_status ON words(status)'); 
    await db.execute('CREATE INDEX idx_nextReviewTime ON words(nextReviewTime)');
    // ✅ 错题索引
    await db.execute('CREATE INDEX idx_isMistake ON words(isMistake)');
    
    await db.execute('CREATE TABLE study_logs (date TEXT PRIMARY KEY, count INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE study_progress (bookName TEXT PRIMARY KEY, currentGroup INTEGER DEFAULT 0, lastReviewTime TEXT)');
  }

  Future<bool> importJsonData(String jsonFileName, String bookName, {bool isShuffle = false}) async {
    if (_isImporting) return false;
    _isImporting = true;
    final db = await instance.database;

    try {
      await db.delete('words', where: 'bookName = ?', whereArgs: [bookName]);
      await db.delete('study_progress', where: 'bookName = ?', whereArgs: [bookName]);

      debugPrint("🚀 正在读取文件: assets/data/$jsonFileName");
      String jsonString = await rootBundle.loadString('assets/data/$jsonFileName');
      final List<dynamic> jsonList = await compute(_parseJson, jsonString);
      
      if (isShuffle) {
        jsonList.shuffle(); 
      }
      
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
      debugPrint("✅ 导入成功！");
      return true; 
    } catch (e) {
      debugPrint("❌ 导入惨败: $e");
      return false; 
    } finally {
      _isImporting = false;
    }
  }

  // ✅ 核心功能：初次学习 (支持标记错题)
  Future<void> markWordAsLearned(int wordId, {bool isMistake = false}) async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now()); 
    DateTime nextReview = DateTime.now().add(const Duration(days: 1));

    await db.transaction((txn) async {
      await txn.update(
        'words', 
        {
          'status': 1, 
          'reviewStage': 1, 
          'nextReviewTime': nextReview.toIso8601String(),
          'isMistake': isMistake ? 1 : 0 // ✅ 如果是“忘记”，加入错题本
        }, 
        where: 'id = ?', 
        whereArgs: [wordId]
      );
      
      await txn.rawInsert('INSERT INTO study_logs (date, count) VALUES (?, 1) ON CONFLICT(date) DO UPDATE SET count = count + 1', [today]);
    });
  }

  // ✅ 核心功能：获取所有错题
  Future<List<Word>> getMistakeWords() async {
    final db = await instance.database;
    // 查找当前书本的错题，或者所有错题？这里暂时查所有错题，或者你可以加 bookName 过滤
    final result = await db.query(
      'words',
      where: 'isMistake = 1',
      orderBy: 'id DESC', // 新错的在前面
    );
    return result.map((json) => Word.fromMap(json)).toList();
  }

  // ✅ 核心功能：移除错题 (斩杀)
  Future<void> removeMistake(int wordId) async {
    final db = await instance.database;
    await db.update(
      'words',
      {'isMistake': 0},
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  Future<void> processReview(int wordId, bool remembered, int currentStage) async {
    final db = await instance.database;
    int newStage;
    DateTime nextReviewDate;

    if (remembered) {
      newStage = currentStage + 1;
      if (newStage > _reviewIntervals.length) {
        nextReviewDate = DateTime.now().add(const Duration(days: 365)); 
      } else {
        int daysToAdd = _reviewIntervals[newStage - 1]; 
        nextReviewDate = DateTime.now().add(Duration(days: daysToAdd));
      }
    } else {
      newStage = 1;
      nextReviewDate = DateTime.now().add(const Duration(days: 1));
    }

    await db.update(
      'words',
      {
        'reviewStage': newStage,
        'nextReviewTime': nextReviewDate.toIso8601String(),
        // 如果复习时又忘了，自动加入错题本；如果记得，不自动移除(需手动斩杀)，或者你可以改成记得就移除
        'isMistake': remembered ? 0 : 1 
      },
      where: 'id = ?',
      whereArgs: [wordId],
    );
  }

  Future<List<Word>> getWordsDueForReview() async {
    final db = await instance.database;
    final nowStr = DateTime.now().toIso8601String();
    final result = await db.query(
      'words',
      where: 'status = 1 AND nextReviewTime <= ?',
      whereArgs: [nowStr],
      orderBy: 'nextReviewTime ASC',
    );
    return result.map((json) => Word.fromMap(json)).toList();
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
  
  Future<List<Word>> getWordsByBook(String bookName) async {
    return getUnlearnedWords(bookName);
  }

  Future<void> devUpdateStat(String date, int count) async {
    final db = await instance.database;
    await db.insert('study_logs', {'date': date, 'count': count}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}