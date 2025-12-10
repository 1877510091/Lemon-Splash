import 'package:flutter/material.dart';
import 'dart:ui';
import 'database_helper.dart';
import 'word_model.dart';

// ======================= 数据模型 =======================

class GlobalData {
  static String currentBook = "四级词汇";
  static Map<String, int> monthlyStats = {
    "2025-12": 125,
    "2025-11": 350,
  };
  static int get todayCount => 42;
}

// ======================= 主程序入口 =======================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fresh Lemon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: Colors.yellow[700],
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF2E7D32),
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow,
          primary: Colors.lime[600]!,
          secondary: Colors.cyan[300]!,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF455A64)),
        ),
      ),
      home: const MainTabScreen(),
    );
  }
}

// ======================= 主框架 =======================

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [const HomePage(), const SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            // 使用新版 API
            backgroundColor: Colors.white.withValues(alpha: 0.7),
            selectedItemColor: Colors.lime[800],
            unselectedItemColor: Colors.cyan[200],
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.bubble_chart_outlined), activeIcon: Icon(Icons.bubble_chart), label: "学习"),
              BottomNavigationBarItem(icon: Icon(Icons.face_outlined), activeIcon: Icon(Icons.face), label: "我的"),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= 1. 首页 =======================

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  // ⚡️ 核心功能：选择书本并导入数据
  void _selectAndImportBook(String bookDisplayName) async {
    Navigator.pop(context); // 关闭弹窗

    // 1. 映射文件名
    String fileName = "";
    if (bookDisplayName == "四级词汇") {
      fileName = "3-CET4-顺序.json";
    } else if (bookDisplayName == "六级词汇") {
      fileName = "4-CET6-顺序.json";
    } else if (bookDisplayName == "考研英语") {
      fileName = "5-考研-顺序.json";
    } else if (bookDisplayName == "托福词汇") {
      fileName = "6-托福-顺序.json";
    } else if (bookDisplayName == "雅思核心") {
      fileName = "雅思真经.json";
    }
    
    if (fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("暂无该词库文件")));
      return;
    }

    // 2. 显示长时间的 Loading 提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          const SizedBox(width: 20),
          Text("正在准备 $bookDisplayName，请稍候..."),
        ]),
        duration: const Duration(seconds: 60), // 设置长一点，防止导入没完成就消失
      )
    );

    // 3. ✅【关键】强制等待 100ms，让 UI 有时间把上面的提示画出来
    await Future.delayed(const Duration(milliseconds: 100));

    // 4. 调用后台线程分批导入
    await DatabaseHelper.instance.importJsonData(fileName, bookDisplayName);

    // 5. 更新状态
    setState(() {
      GlobalData.currentBook = bookDisplayName;
    });
    
    if(mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // 隐藏 Loading
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 词库切换成功！")));
    }
  }

  void _showBookSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 5,
                margin: const EdgeInsets.only(top: 15, bottom: 10),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("选择你的词库", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
              ),
              _buildBookItem("四级词汇", "CET-4"),
              _buildBookItem("六级词汇", "CET-6"),
              _buildBookItem("考研英语", "Postgraduate"),
              _buildBookItem("托福词汇", "TOEFL"),
              _buildBookItem("雅思核心", "IELTS"),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookItem(String name, String sub) {
    bool isSelected = name == GlobalData.currentBook;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isSelected ? Colors.lime[100] : Colors.grey[100], shape: BoxShape.circle),
        child: Icon(Icons.book, color: isSelected ? Colors.lime[800] : Colors.grey),
      ),
      title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.grey[700])),
      subtitle: Text(sub),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.lime) : null,
      onTap: () => _selectAndImportBook(name), 
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'), 
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.6),
                Colors.white.withValues(alpha: 0.2)
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.eco, color: Colors.lime[800], size: 28),
                      const SizedBox(width: 10),
                      Text("Lemon\nSplash", style: TextStyle(fontSize: 28, height: 1.0, fontFamily: 'Georgia', fontWeight: FontWeight.bold, color: Colors.teal[800])),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("🚧 更多功能正在开发中..."), duration: Duration(seconds: 2),)
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.lime, width: 2)),
                          child: const CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.grey)),
                        ),
                      )
                    ],
                  ),

                  const Spacer(flex: 1),

                  _buildGlassCard(
                    icon: Icons.menu_book,
                    title: "正在学习",
                    value: GlobalData.currentBook,
                    color: Colors.cyan,
                    onTap: _showBookSelection,
                  ),

                  const SizedBox(height: 20),

                  _buildGlassCard(
                    icon: Icons.water_drop,
                    title: "今日学习",
                    value: "${GlobalData.todayCount} 个单词",
                    color: Colors.lime,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StatsPage())),
                  ),

                  const Spacer(flex: 2),

                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WordLearningPage())),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                          color: Colors.yellow[400],
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(color: Colors.yellow[700]!.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10)),
                            const BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(0, -5))
                          ],
                          gradient: LinearGradient(
                            colors: [Colors.yellow[300]!, Colors.lime[300]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.teal[800], size: 36),
                          const SizedBox(width: 10),
                          Text("开始学习", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.teal[800])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required IconData icon, required String title, required String value, required MaterialColor color, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withValues(alpha: 0.4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: color[50], shape: BoxShape.circle),
                      child: Icon(icon, color: color[700], size: 28),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                        Text(value, style: TextStyle(color: color[900], fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Georgia')),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, color: color[200], size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ====================== 统计页面 ======================
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final statsList = GlobalData.monthlyStats.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(title: const Text("每月学习记录")),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: statsList.length,
        itemBuilder: (context, index) {
          final entry = statsList[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              leading: Text("${index + 1}", style: TextStyle(fontSize: 20, color: Colors.grey[300], fontWeight: FontWeight.bold)),
              title: Text(entry.key, style: TextStyle(fontSize: 18, color: Colors.teal[800], fontWeight: FontWeight.bold)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.lime[100], borderRadius: BorderRadius.circular(10)),
                child: Text("${entry.value}", style: TextStyle(color: Colors.lime[900], fontWeight: FontWeight.bold)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ======================= 设置页面 =======================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _tap = 0; 
  bool _dev = false;

  void _handleVersionTap() {
    setState(() {
      _tap++;
      if (_tap >= 3) {
        if (!_dev) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 开发者模式已开启！")));
        }
        _dev = true;
        _showDeveloperDialog(); 
      }
    });
  }

  void _showDeveloperDialog() {
    final monthController = TextEditingController(text: "2025-01");
    final countController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("开发者后台"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("修改历史背词数据", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(controller: monthController, decoration: const InputDecoration(labelText: "月份 (YYYY-MM)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: countController, decoration: const InputDecoration(labelText: "数量", border: OutlineInputBorder()), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          ElevatedButton(
            onPressed: () {
              if (monthController.text.isNotEmpty && countController.text.isNotEmpty) {
                GlobalData.monthlyStats[monthController.text] = int.parse(countController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("数据修改成功！")));
              }
            },
            child: const Text("保存"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("设置")),
      body: ListView(
        children: [
          const SizedBox(height: 10),
          _buildSectionHeader("关于"),
          const ListTile(leading: Icon(Icons.info_outline_rounded, color: Colors.blue), title: Text("软件信息"), subtitle: Text("Lemon Splash v1.3")),
          const ListTile(leading: Icon(Icons.face_rounded, color: Colors.orange), title: Text("作者"), subtitle: Text("QQ:187510091")),
          const Divider(height: 40, indent: 20, endIndent: 20),
          _buildSectionHeader("系统"),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined, color: Colors.purple),
            title: const Text("版本号"),
            subtitle: const Text("v1.0.3 (Build 2025)"),
            onTap: _handleVersionTap,
          ),
          if (_dev) 
          Container(
              margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const Icon(Icons.bug_report_rounded, color: Colors.red),
                title: const Text("开发者选项", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text("自定义背词数据"),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.red),
                onTap: _showDeveloperDialog,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(title, style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

// ======================= 4. 背单词页面 (连接真实数据库) =======================

class WordLearningPage extends StatefulWidget {
  const WordLearningPage({super.key});
  @override
  State<WordLearningPage> createState() => _WordLearningPageState();
}

class _WordLearningPageState extends State<WordLearningPage> {
  List<Word> words = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    // 1. 尝试从数据库读取
    List<Word> dbWords = await DatabaseHelper.instance.getWordsByBook(GlobalData.currentBook);

    // 2. 如果没数据（可能是刚安装），默认加载“四级词汇”
    if (dbWords.isEmpty) {
      await DatabaseHelper.instance.importJsonData("3-CET4-顺序.json", "四级词汇");
      GlobalData.currentBook = "四级词汇";
      dbWords = await DatabaseHelper.instance.getWordsByBook("四级词汇");
    }

    if (mounted) {
      setState(() {
        words = dbWords;
        _isLoading = false;
      });
    }
  }

  void _nextWord() {
    setState(() {
      if (_currentIndex < words.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0; 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 本轮学习完成！重新开始。")));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.lime)));
    }
    
    if (words.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("暂无数据，请在首页重新选择词库")),
      );
    }

    final currentWord = words[_currentIndex];
    
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: AppBar(
        leading: const BackButton(color: Colors.teal),
        backgroundColor: Colors.transparent,
        title: Text("进度: ${_currentIndex + 1}/${words.length}", style: TextStyle(color: Colors.teal[800], fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(color: Colors.teal.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 15))
                ],
              ),
              child: Column(
                children: [
                  // 单词
                  Text(
                    currentWord.word, 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal[900], fontFamily: 'Georgia')
                  ),
                  const SizedBox(height: 10),
                  // 音标 (如果有)
                  if (currentWord.phonetic.isNotEmpty) 
                    Text("/${currentWord.phonetic}/", style: TextStyle(fontSize: 20, color: Colors.lime[700])),
                  const SizedBox(height: 30),
                  // 释义
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Text(
                        currentWord.definition, 
                        textAlign: TextAlign.center, 
                        style: TextStyle(fontSize: 18, color: Colors.grey[600], height: 1.5)
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionBtn(Icons.close, Colors.red[50]!, Colors.red[300]!, "忘记", _nextWord),
                _actionBtn(Icons.check, Colors.lime[100]!, Colors.lime[800]!, "认识", _nextWord),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color bg, Color fg, String label, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Column(
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold))
        ],
      ),
    );
  }
} 