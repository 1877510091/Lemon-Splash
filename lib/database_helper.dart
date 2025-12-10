import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart'; // 必须引用，用于使用 compute 和 debugPrint
import 'word_model.dart';

// ✅ 顶级函数：在后台线程解析 JSON，避免占用主线程
List<dynamic> _parseJson(String jsonString) {
  return json.decode(jsonString);
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  bool _isImporting = false; // 🔒 锁：防止用户疯狂点击重复导入

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lemon_words.db');
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
      status INTEGER DEFAULT 0
    )
    ''');
    // ✅ 创建索引，加快查询速度
    await db.execute('CREATE INDEX idx_bookName ON words(bookName)');
  }

  // 检查某本书是否已经导入过
  Future<bool> isBookImported(String bookName) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE bookName = ?',
      [bookName]
    );
    int count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  // ✅ 核心优化：分批导入数据，防止卡死
  Future<void> importJsonData(String jsonFileName, String bookName) async {
    if (_isImporting) {
      debugPrint("⚠️ 正在导入中，请勿重复操作");
      return;
    }
    _isImporting = true;

    final db = await instance.database;

    // 1. 检查是否已存在
    if (await isBookImported(bookName)) {
      debugPrint("📚 $bookName 之前已导入，跳过。");
      _isImporting = false;
      return;
    }

    debugPrint("🚀 开始读取文件: $bookName ...");
    
    try {
      // 2. 读取文件
      String jsonString = await rootBundle.loadString('assets/data/$jsonFileName');

      // 3. 后台线程解析 JSON
      final List<dynamic> jsonList = await compute(_parseJson, jsonString);
      debugPrint("📄 解析完成，共 ${jsonList.length} 个单词，准备分批写入...");

      // 4. ✅【关键优化】分批写入，每批 100 个
      // 如果一次性写入 5000 个，界面必卡死。分批写可以让 UI 线程有机会刷新。
      const int batchSize = 100; 
      
      for (var i = 0; i < jsonList.length; i += batchSize) {
        // 计算当前批次的结束位置
        var end = (i + batchSize < jsonList.length) ? i + batchSize : jsonList.length;
        // 截取当前批次的数据
        var currentBatchList = jsonList.sublist(i, end);

        // 开启事务进行批量插入
        await db.transaction((txn) async {
          var batch = txn.batch();
          for (var item in currentBatchList) {
            try {
               Word w = Word.fromJson(item, bookName);
               batch.insert('words', w.toMap());
            } catch (e) {
               // 容错：跳过格式错误的数据，不影响整体
            }
          }
          await batch.commit(noResult: true);
        });

        // ✅【核心】暂停 1 毫秒，把控制权交还给 UI 线程，让加载圈转起来
        await Future.delayed(const Duration(milliseconds: 1));
      }
      
      debugPrint("✅ $bookName 全部导入完成！");
    } catch (e) {
      debugPrint("❌ 导入失败 ($jsonFileName): $e");
    } finally {
      _isImporting = false; // 无论成功失败，都要释放锁
    }
  }

  // 获取单词
  Future<List<Word>> getWordsByBook(String bookName) async {
    final db = await instance.database;
    // 随机获取单词，限制 50 个防止加载过慢
    final result = await db.query(
      'words', 
      where: 'bookName = ?', 
      whereArgs: [bookName],
      orderBy: 'RANDOM()', 
      limit: 50 
    );
    return result.map((json) => Word.fromMap(json)).toList();
  }
}