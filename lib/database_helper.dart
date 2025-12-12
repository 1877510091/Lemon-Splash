import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart'; 
import 'package:intl/intl.dart'; 
import 'word_model.dart';

List<dynamic> _parseAndDecode(String jsonString) {
  try {
    return jsonDecode(jsonString); 
  } catch (e) {
    List<dynamic> list = [];
    LineSplitter.split(jsonString).forEach((line) {
      if (line.trim().isNotEmpty) {
        try {
          list.add(jsonDecode(line));
        } catch (_) {}
      }
    });
    return list;
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  bool _isImporting = false; 

  static final List<int> _reviewIntervals = [1, 2, 4, 7, 15, 30];

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    // ✅ 升级版本号 v8 (触发新逻辑)
    _database = await _initDB('lemon_words_v8.db'); 
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
      word TEXT, 
      phonetic TEXT, 
      definition TEXT, 
      bookName TEXT, 
      status INTEGER DEFAULT 0,
      reviewStage INTEGER DEFAULT 0,
      nextReviewTime TEXT,
      isMistake INTEGER DEFAULT 0,
      example TEXT
    )''');
    await db.execute('CREATE INDEX idx_bookName ON words(bookName)');
    await db.execute('CREATE INDEX idx_status ON words(status)'); 
    
    await db.execute('CREATE TABLE study_logs (date TEXT PRIMARY KEY, count INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE study_progress (bookName TEXT PRIMARY KEY, currentGroup INTEGER DEFAULT 0, lastReviewTime TEXT)');
    await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
  }

  Future<void> setLastBook(String bookName) async {
    final db = await instance.database;
    await db.insert('settings', {'key': 'last_book', 'value': bookName}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getLastBook() async {
    final db = await instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: ['last_book']);
    if (res.isNotEmpty) {
      return res.first['value'] as String;
    }
    return null;
  }

  // ==================== 终极兼容导入逻辑 (适配 phrases) ====================
  Future<bool> importJsonData(String jsonFileName, String bookName, {bool isShuffle = false}) async {
    if (_isImporting) {
      return false;
    }
    _isImporting = true;
    final db = await instance.database;

    try {
      String path = jsonFileName.startsWith('assets') ? jsonFileName : 'assets/data/$jsonFileName';
      debugPrint("🚀 准备读取: $path");

      String jsonString;
      try {
        jsonString = await rootBundle.loadString(path);
      } catch (e) {
        debugPrint("❌ 文件读取失败: $e");
        return false;
      }

      final List<dynamic> jsonList = await compute(_parseAndDecode, jsonString);
      
      if (jsonList.isEmpty) {
        return false;
      }
      if (isShuffle) {
        jsonList.shuffle(); 
      }
      
      await db.transaction((txn) async {
        await txn.delete('words', where: 'bookName = ?', whereArgs: [bookName]);
        await txn.delete('study_progress', where: 'bookName = ?', whereArgs: [bookName]);

        var batch = txn.batch();
        
        for (var item in jsonList) {
          // 1. 提取单词
          String word = "";
          if (item['headWord'] != null) {
            word = item['headWord'];
          } else if (item['word'] != null) {
            word = (item['word'] is Map) ? item['word']['wordHead'] : item['word'];
          }
          
          if (word.isEmpty) {
            continue; 
          }

          String phonetic = "";
          String definition = "";
          String example = "";

          // 2. 尝试从深层结构提取 (BEC/小学格式)
          bool foundDeep = false;
          try {
            var deep = _getDeepValue(item, ['content', 'word', 'content']);
            if (deep != null) {
              // 音标
              phonetic = deep['usphone'] ?? deep['ukphone'] ?? "";
              
              // 释义
              if (deep['trans'] != null) {
                definition = _parseDefinitionList(deep['trans']);
                foundDeep = true;
              }

              // 例句 (sentences)
              if (deep['sentence'] != null && deep['sentence']['sentences'] != null) {
                var sList = deep['sentence']['sentences'];
                if (sList is List && sList.isNotEmpty) {
                  var s = sList[0];
                  String en = s['sContent'] ?? "";
                  String cn = s['sCn'] ?? "";
                  if (en.isNotEmpty) {
                    example = "$en\n$cn";
                  }
                }
              }
            }
          } catch (_) {}

          // 3. 尝试从外层结构提取 (你刚刚发的格式 / 四级 / 考研)
          if (!foundDeep) {
            // 音标
            if (phonetic.isEmpty) {
              phonetic = item['phonetic'] ?? item['usphone'] ?? "";
            }

            // 释义 (trans / definition / translations)
            // 你发的格式里 key 是 "translations"
            var flatTrans = item['translations'] ?? item['trans'] ?? item['definition'] ?? item['translations'];
            if (flatTrans != null) {
              definition = _parseDefinitionList(flatTrans);
            }

            // 例句 (phrases / examples)
            // ✅ 专门适配你刚刚发的 {"phrases": [...]} 格式
            if (example.isEmpty && item['phrases'] != null && item['phrases'] is List) {
              List phrases = item['phrases'];
              // 取前3个短语，避免太长
              example = phrases.take(3).map((p) {
                String en = p['phrase'] ?? "";
                String cn = p['translation'] ?? "";
                return "$en\n$cn";
              }).join('\n\n');
            }
          }

          batch.insert('words', {
            'bookName': bookName,
            'word': word,
            'phonetic': phonetic,
            'definition': definition,
            'example': example,
            'status': 0,
            'isMistake': 0,
            'reviewStage': 0
          });
        }
        await batch.commit(noResult: true);
      });

      await saveStudyProgress(StudyProgress(bookName: bookName, currentGroup: 0));
      await setLastBook(bookName); 
      debugPrint("✅ 导入成功: ${jsonList.length} 词");
      return true; 
    } catch (e) {
      debugPrint("❌ 导入出错: $e");
      return false; 
    } finally {
      _isImporting = false;
    }
  }

  // --- 辅助工具 ---

  // 这里的逻辑修复了 adj./v. 丢失的问题
  String _parseDefinitionList(dynamic data) {
    if (data is String) {
      return data; 
    }
    if (data is List) {
      return data.map((item) {
        if (item is String) {
          return item; 
        }
        if (item is Map) {
          // 适配多种 key 名：
          // type: 你刚刚发的格式
          // pos: BEC 格式
          String pos = item['pos'] ?? item['type'] ?? "";
          
          // translation: 你刚刚发的格式
          // tranCn / tran: BEC 格式
          String cn = item['translation'] ?? item['tranCn'] ?? item['tran'] ?? item['text'] ?? "";
          
          return pos.isNotEmpty ? "$pos. $cn" : cn;
        }
        return item.toString();
      }).join('\n');
    }
    return "";
  }

  // 深度查找器
  dynamic _getDeepValue(Map data, List<String> path) {
    dynamic current = data;
    for (String key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

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
          'isMistake': isMistake ? 1 : 0 
        }, 
        where: 'id = ?', 
        whereArgs: [wordId]
      );
      await txn.rawInsert('INSERT INTO study_logs (date, count) VALUES (?, 1) ON CONFLICT(date) DO UPDATE SET count = count + 1', [today]);
    });
  }

  Future<List<Word>> getWordsByGroup(String bookName, int groupIndex, {int size = 20}) async {
    final db = await instance.database;
    final offset = groupIndex * size;
    final result = await db.query('words', where: 'bookName = ?', whereArgs: [bookName], orderBy: 'id ASC', limit: size, offset: offset);
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<List<Word>> getMistakeWords() async {
    final db = await instance.database;
    final result = await db.query('words', where: 'isMistake = 1', orderBy: 'id DESC');
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<void> removeMistake(int wordId) async {
    final db = await instance.database;
    await db.update('words', {'isMistake': 0}, where: 'id = ?', whereArgs: [wordId]);
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
        nextReviewDate = DateTime.now().add(Duration(days: _reviewIntervals[newStage - 1]));
      }
    } else {
      newStage = 1;
      nextReviewDate = DateTime.now().add(const Duration(days: 1));
    }

    await db.update('words', {
      'reviewStage': newStage,
      'nextReviewTime': nextReviewDate.toIso8601String(),
      'isMistake': remembered ? 0 : 1 
    }, where: 'id = ?', whereArgs: [wordId]);
  }

  Future<List<Word>> getWordsDueForReview() async {
    final db = await instance.database;
    final nowStr = DateTime.now().toIso8601String();
    final result = await db.query('words', where: 'status = 1 AND nextReviewTime <= ?', whereArgs: [nowStr], orderBy: 'nextReviewTime ASC');
    return result.map((json) => Word.fromMap(json)).toList();
  }

  Future<int> getTodayCount() async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await db.query('study_logs', where: 'date = ?', whereArgs: [today]);
    if (result.isNotEmpty) {
      return result.first['count'] as int;
    }
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
    if (res.isNotEmpty) {
      return StudyProgress.fromMap(res.first);
    }
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

  Future<void> devUpdateStat(String date, int count) async {
    final db = await instance.database;
    await db.insert('study_logs', {'date': date, 'count': count}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}