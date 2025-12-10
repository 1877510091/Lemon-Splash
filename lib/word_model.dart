// ✅ 修复：删除了未使用的 import 'dart:convert';
class Word {
  final int? id;
  final String word;       // 单词拼写
  final String phonetic;   // 音标
  final String definition; // 中文释义
  final String bookName;   // 所属书名
  int status;              // 0:未学, 1:认识, 2:忘记

  Word({
    this.id,
    required this.word,
    required this.phonetic,
    required this.definition,
    required this.bookName,
    this.status = 0,
  });

  // 1. 数据库 -> 对象
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      word: map['word'] ?? '',
      phonetic: map['phonetic'] ?? '',
      definition: map['definition'] ?? '',
      bookName: map['bookName'] ?? '',
      status: map['status'] ?? 0,
    );
  }

  // 2. 对象 -> 数据库
  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'phonetic': phonetic,
      'definition': definition,
      'bookName': bookName,
      'status': status,
    };
  }

  // 3. 【核心】解析你的 JSON 文件格式
  factory Word.fromJson(Map<String, dynamic> json, String bookName) {
    // 你的JSON里翻译在 'translations' 数组里，我们需要把它拼成一个字符串
    String defStr = "";
    // ✅ 修复：给 if 语句添加花括号
    if (json['translations'] != null) {
      List<dynamic> transList = json['translations'];
      // 拼接成 "n. 放弃; v. 抛弃" 的形式
      defStr = transList.map((t) {
        String type = t['type'] ?? '';
        String trans = t['translation'] ?? '';
        return "$type. $trans";
      }).join('\n');
    }
    
    // 你的JSON可能没有 'phonetic' 字段，这里做一个防空处理
    String phone = json['phonetic'] ?? ''; 

    return Word(
      word: json['word'] ?? '', 
      phonetic: phone,
      definition: defStr,
      bookName: bookName,
      status: 0,
    );
  }
}