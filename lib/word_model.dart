class Word {
  final int? id;
  final String word;
  final String phonetic;
  final String definition;
  final String bookName;
  int status; // 0:未学, 1:已学/复习中
  
  // 艾宾浩斯字段
  int reviewStage; 
  String? nextReviewTime;
  
  // ✅ 新增：错题标记 (0:正常, 1:错题)
  int isMistake; 

  Word({
    this.id,
    required this.word,
    required this.phonetic,
    required this.definition,
    required this.bookName,
    this.status = 0,
    this.reviewStage = 0,
    this.nextReviewTime,
    this.isMistake = 0, // 默认为 0
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      word: map['word'] ?? '',
      phonetic: map['phonetic'] ?? '',
      definition: map['definition'] ?? '',
      bookName: map['bookName'] ?? '',
      status: map['status'] ?? 0,
      reviewStage: map['reviewStage'] ?? 0,
      nextReviewTime: map['nextReviewTime'],
      isMistake: map['isMistake'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'phonetic': phonetic,
      'definition': definition,
      'bookName': bookName,
      'status': status,
      'reviewStage': reviewStage,
      'nextReviewTime': nextReviewTime,
      'isMistake': isMistake,
    };
  }

  factory Word.fromJson(Map<String, dynamic> json, String bookName) {
    if (json.containsKey('headWord') && json.containsKey('content')) {
      try {
        var contentObj = json['content'];
        var wordObj = contentObj['word'];
        var coreContent = wordObj['content'];
        String w = wordObj['wordHead'] ?? json['headWord'] ?? '';
        String p = coreContent['usphone'] ?? coreContent['ukphone'] ?? coreContent['phone'] ?? '';
        String def = "";
        if (coreContent['trans'] != null) {
          List<dynamic> transList = coreContent['trans'];
          def = transList.map((t) {
            String pos = t['pos'] ?? '';
            String cn = t['tranCn'] ?? '';
            if (pos.endsWith('.')) pos = pos.substring(0, pos.length - 1);
            return "$pos. $cn";
          }).join('\n');
        }
        return Word(word: w, phonetic: p, definition: def, bookName: bookName, status: 0);
      } catch (e) {
        return Word(word: "Error", phonetic: "", definition: "解析失败", bookName: bookName);
      }
    }
    String defStr = "";
    if (json['translations'] != null) {
      List<dynamic> transList = json['translations'];
      defStr = transList.map((t) {
        String type = t['type'] ?? '';
        String trans = t['translation'] ?? '';
        return "$type. $trans";
      }).join('\n');
    }
    if (defStr.isEmpty && json['definition'] != null) defStr = json['definition'];
    return Word(word: json['word'] ?? '', phonetic: json['phonetic'] ?? '', definition: defStr, bookName: bookName, status: 0);
  }
}

class StudyProgress {
  final String bookName;
  int currentGroup;
  DateTime? lastReviewTime;

  StudyProgress({required this.bookName, required this.currentGroup, this.lastReviewTime});

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
      currentGroup: map['currentGroup'],
      lastReviewTime: map['lastReviewTime'] != null ? DateTime.parse(map['lastReviewTime']) : null,
    );
  }
}