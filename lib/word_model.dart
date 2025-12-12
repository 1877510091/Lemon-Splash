class Word {
  final int? id;
  final String word;
  final String phonetic;
  final String definition;
  final String bookName;
  final int status; // 0:未学, 1:已学
  final int reviewStage;
  final DateTime? nextReviewTime;
  final bool isMistake;
  final String example; // ✅ 新增：例句字段

  Word({
    this.id,
    required this.word,
    required this.phonetic,
    required this.definition,
    required this.bookName,
    this.status = 0,
    this.reviewStage = 0,
    this.nextReviewTime,
    this.isMistake = false,
    this.example = "", // 默认为空
  });

  // 转换成 Map 保存到数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'phonetic': phonetic,
      'definition': definition,
      'bookName': bookName,
      'status': status,
      'reviewStage': reviewStage,
      'nextReviewTime': nextReviewTime?.toIso8601String(),
      'isMistake': isMistake ? 1 : 0,
      'example': example, // ✅ 保存例句
    };
  }

  // 从数据库 Map 恢复
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      word: map['word'],
      phonetic: map['phonetic'] ?? "",
      definition: map['definition'] ?? "",
      bookName: map['bookName'],
      status: map['status'] ?? 0,
      reviewStage: map['reviewStage'] ?? 0,
      nextReviewTime: map['nextReviewTime'] != null ? DateTime.parse(map['nextReviewTime']) : null,
      isMistake: (map['isMistake'] ?? 0) == 1,
      example: map['example'] ?? "", // ✅ 读取例句
    );
  }
}

class StudyProgress {
  final String bookName;
  int currentGroup;
  DateTime? lastReviewTime;

  StudyProgress({required this.bookName, this.currentGroup = 0, this.lastReviewTime});

  Map<String, dynamic> toMap() {
    return {
      'bookName': bookName,
      'currentGroup': currentGroup,
      'lastReviewTime': lastReviewTime?.toIso8601String(),
    };
  }

  factory StudyProgress.fromMap(Map<String, dynamic> map) {
    return StudyProgress(
      bookName: map['bookName'],
      currentGroup: map['currentGroup'] ?? 0,
      lastReviewTime: map['lastReviewTime'] != null ? DateTime.parse(map['lastReviewTime']) : null,
    );
  }
}