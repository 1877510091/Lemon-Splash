import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'word_model.dart';

// ======================= 1. 全局状态 =======================
class GlobalData {
  static String currentBook = "四级词汇";
  static Map<String, Map<int, int>> loadedMonthData = {}; 
  static ValueNotifier<int> todayCountNotifier = ValueNotifier(0);
  
  static Future<void> refreshTodayCount() async {
    todayCountNotifier.value = await DatabaseHelper.instance.getTodayCount();
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white, 
  ));
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
        primaryColor: Colors.yellow[700],
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, 
          foregroundColor: Color(0xFF2E7D32), 
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow, 
          primary: Colors.lime[600]!, 
          secondary: Colors.cyan[300]!
        ),
      ),
      home: const MainTabScreen(),
    );
  }
}

// ======================= 2. 主框架 =======================
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});
  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [const HomePage(), const SettingsPage()];
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    GlobalData.refreshTodayCount();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        if (_lastPressedAt == null || DateTime.now().difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = DateTime.now();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("再按一次退出应用"), duration: Duration(seconds: 2))
            );
          }
          return; 
        }
        await SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: true,
        body: _pages[_currentIndex],
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
                if (index == 0) GlobalData.refreshTodayCount();
              },
              backgroundColor: Colors.white.withValues(alpha: 0.8),
              selectedItemColor: Colors.lime[800],
              unselectedItemColor: Colors.grey[400],
              showUnselectedLabels: false,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.bubble_chart_outlined), activeIcon: Icon(Icons.bubble_chart), label: "学习"),
                BottomNavigationBarItem(icon: Icon(Icons.face_outlined), activeIcon: Icon(Icons.face), label: "我的"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= 3. 首页 =======================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/bg.jpg'), fit: BoxFit.cover),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0.3)],
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
                      Text("Lemon\nSplash", style: TextStyle(fontSize: 24, height: 1.0, fontFamily: 'Georgia', fontWeight: FontWeight.bold, color: Colors.teal[800])),
                      const Spacer(),
                      const CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.grey)),
                    ],
                  ),
                  const Spacer(flex: 1),

                  LemonGlassCard(
                    icon: Icons.menu_book,
                    title: "正在学习",
                    value: GlobalData.currentBook,
                    color: Colors.cyan,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (c) => const BookLibraryPage()));
                      if (mounted) setState(() {}); 
                    },
                  ),
                  const SizedBox(height: 20),

                  ValueListenableBuilder<int>(
                    valueListenable: GlobalData.todayCountNotifier,
                    builder: (context, count, _) {
                      return LemonGlassCard(
                        icon: Icons.water_drop,
                        title: "今日收集",
                        value: "$count 滴",
                        color: Colors.lime,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StatsPage())),
                      );
                    },
                  ),

                  const Spacer(flex: 2),

                  GestureDetector(
                    onTap: () async {
                       await Navigator.push(context, MaterialPageRoute(builder: (c) => const WordLearningPage()));
                       if (mounted) GlobalData.refreshTodayCount();
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.yellow[400], borderRadius: BorderRadius.circular(40),
                        boxShadow: [BoxShadow(color: Colors.yellow[700]!.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))],
                        gradient: LinearGradient(colors: [Colors.yellow[300]!, Colors.lime[300]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.teal[800], size: 36),
                          const SizedBox(width: 10),
                          Text("Start Fresh", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.teal[800])),
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
}

class LemonGlassCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final MaterialColor color;
  final VoidCallback onTap;

  const LemonGlassCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withValues(alpha: 0.5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color[50], shape: BoxShape.circle), child: Icon(icon, color: color[700], size: 28)),
                    const SizedBox(width: 20),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 14)), Text(value, style: TextStyle(color: color[900], fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Georgia'))]),
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

// ======================= 4. 词库图书馆 (包含12本词库) =======================
class BookLibraryPage extends StatefulWidget {
  const BookLibraryPage({super.key});
  @override
  State<BookLibraryPage> createState() => _BookLibraryPageState();
}

class _BookLibraryPageState extends State<BookLibraryPage> {
  
  void _import(String name, String file) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Row(children: [const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), const SizedBox(width: 20), Text("正在导入 $name...")]), duration: const Duration(seconds: 60))
    );
    
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    await DatabaseHelper.instance.importJsonData(file, name);
    GlobalData.currentBook = name;
    
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 词库切换成功！")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/bg.jpg'), fit: BoxFit.cover)),
        child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.6)])),
          child: SafeArea(
            child: Column(
              children: [
                AppBar(title: const Text("柠檬图书馆"), backgroundColor: Colors.transparent, centerTitle: true),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // 第一梯队：大学核心
                      _item("四级词汇", "CET-4", "3-CET4-顺序.json", Colors.teal),
                      _item("六级词汇", "CET-6", "4-CET6-顺序.json", Colors.indigo),
                      _item("考研英语", "Postgraduate", "5-考研-顺序.json", Colors.deepOrange),
                      const Divider(height: 30),
                      
                      // 第二梯队：留学
                      _item("雅思核心", "IELTS", "雅思真经.json", Colors.blue),
                      _item("托福词汇", "TOEFL", "6-托福-顺序.json", Colors.purple),
                      const Divider(height: 30),

                      // 第三梯队：K12
                      _item("小学英语", "Grade 1-6", "小学英语1-6年级.json", Colors.green),
                      _item("初中英语", "Junior High", "1-初中-顺序.json", Colors.lightGreen),
                      _item("高中英语", "Senior High", "2-高中-顺序.json", Colors.lime),
                      const Divider(height: 30),

                      // 第四梯队：专业
                      _item("专业四级", "TEM-4", "专四.json", Colors.brown),
                      _item("专业八级", "TEM-8", "专八.json", Colors.red),
                      const Divider(height: 30),

                      // 第五梯队：高级/商务
                      _item("SAT词汇", "SAT", "7-SAT-顺序.json", Colors.amber),
                      _item("BEC商务", "Business", "BEC商务英语.json", Colors.blueGrey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(String title, String sub, String file, MaterialColor color) {
    bool isCur = GlobalData.currentBook == title;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: isCur ? Border.all(color: Colors.lime, width: 2) : null),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color[50], borderRadius: BorderRadius.circular(12)), child: Icon(Icons.book, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(sub),
        trailing: isCur ? const Icon(Icons.check_circle, color: Colors.lime) : const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        onTap: () => _import(title, file),
      ),
    );
  }
}

// ======================= 5. 统计页面 =======================
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int _expandedIndex = -1;
  List<String> _months = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initMonths();
  }

  void _initMonths() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery("SELECT MIN(date) as d FROM study_logs");
    
    DateTime startDate = DateTime.now(); 
    if (result.isNotEmpty && result.first['d'] != null) {
      startDate = DateTime.parse(result.first['d'] as String);
    }
    
    List<String> list = [];
    DateTime now = DateTime.now();
    
    for (int i = 0; i < 24; i++) {
       DateTime targetDate = DateTime(now.year, now.month - i, 1);
       DateTime startMonth = DateTime(startDate.year, startDate.month, 1);
       if (targetDate.isBefore(startMonth)) break;
       list.add(DateFormat('yyyy-MM').format(targetDate));
    }
    
    if (mounted) {
      setState(() {
        _months = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMonthData(String month) async {
    if (GlobalData.loadedMonthData.containsKey(month)) return;
    int year = int.parse(month.split('-')[0]);
    int m = int.parse(month.split('-')[1]);
    var data = await DatabaseHelper.instance.getMonthlyData(year, m);
    if (mounted) {
      setState(() {
        GlobalData.loadedMonthData[month] = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(title: const Text("学习足迹")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.lime))
        : _months.isEmpty 
          ? Center(child: Text("暂无记录，快去背个单词吧！", style: TextStyle(color: Colors.grey[600])))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _months.length,
              itemBuilder: (context, index) {
                String month = _months[index];
                bool isExpanded = _expandedIndex == index;
                int totalCount = 0;
                if (GlobalData.loadedMonthData.containsKey(month)) {
                   totalCount = GlobalData.loadedMonthData[month]!.values.fold(0, (sum, val) => sum + val);
                }

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(backgroundColor: Colors.lime[100], child: const Icon(Icons.calendar_today, color: Colors.lime)),
                        title: Text(month, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal)),
                        subtitle: isExpanded ? Text("本月共学习 $totalCount 个单词") : null,
                        trailing: Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                        onTap: () {
                          setState(() => _expandedIndex = isExpanded ? -1 : index);
                          if (_expandedIndex == index) _loadMonthData(month);
                        },
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: isExpanded ? 220 : 0,
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
                      child: isExpanded ? _buildChart(month) : null,
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildChart(String month) {
    var data = GlobalData.loadedMonthData[month];
    if (data == null) return const Center(child: CircularProgressIndicator(color: Colors.lime));
    if (data.isEmpty) return const Center(child: Text("本月太懒了，还没有学习记录哦 ~", style: TextStyle(color: Colors.grey)));

    List<FlSpot> spots = [];
    double maxVal = 0;
    for (int i = 1; i <= 31; i++) {
      int count = data[i] ?? 0;
      if (count > maxVal) maxVal = count.toDouble();
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    return LineChart(
      LineChartData(
        maxY: (maxVal < 5) ? 5 : maxVal * 1.2,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 5, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)))),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots, isCurved: true, color: Colors.teal, barWidth: 3, dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.teal.withValues(alpha: 0.1)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Colors.teal,
            getTooltipItems: (spots) => spots.map((spot) => LineTooltipItem("${spot.x.toInt()}日\n${spot.y.toInt()}词", const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList()
          )
        ),
      ),
    );
  }
}

// ======================= 6. 设置页面 =======================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Timer? _timer;
  int _count = 0;
  bool _dev = false;

  void _tapVer() {
    _count++;
    if (_timer == null || !_timer!.isActive) {
      _timer = Timer(const Duration(seconds: 2), () { 
        if(mounted) setState(() => _count = 0); 
      });
    }
    if (_count >= 5) {
      if (!_dev) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🚀 开发者模式已激活！")));
      setState(() => _dev = true);
      _timer?.cancel();
      _count = 0;
    }
  }

  void _editData() {
    final dCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final cCtrl = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("修改数据"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: dCtrl, decoration: const InputDecoration(labelText: "日期 (YYYY-MM-DD)")),
        TextField(controller: cCtrl, decoration: const InputDecoration(labelText: "数量"), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(
          onPressed: ()=>Navigator.pop(c), 
          child: const Text("取消")
        ),
        TextButton(
          onPressed: () async {
            if (dCtrl.text.isNotEmpty && cCtrl.text.isNotEmpty) {
              await DatabaseHelper.instance.devUpdateStat(dCtrl.text, int.parse(cCtrl.text));
              if (!c.mounted) return;
              Navigator.pop(c);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("修改成功，去统计页刷新看看")));
                GlobalData.loadedMonthData.clear();
                // 刷新页面重新加载月份列表
                setState(() {});
              }
            }
          }, 
          child: const Text("确定")
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("设置")),
      body: ListView(children: [
        const ListTile(leading: Icon(Icons.info_outline, color: Colors.blue), title: Text("软件信息"), subtitle: Text("柠檬单词 v1.3")),
        const ListTile(leading: Icon(Icons.face, color: Colors.orange), title: Text("作者"), subtitle: Text("QQ:187510091  小郭同学")),
        const Divider(),
        ListTile(leading: const Icon(Icons.verified, color: Colors.purple), title: const Text("版本号"), subtitle: const Text("v2.1.0 (Build 2025)"), onTap: _tapVer),
        if (_dev) Container(color: Colors.red[50], child: ListTile(leading: const Icon(Icons.bug_report, color: Colors.red), title: const Text("修改历史数据"), onTap: _editData)),
      ]),
    );
  }
}

// ======================= 7. 背单词页面 =======================
class WordLearningPage extends StatefulWidget {
  const WordLearningPage({super.key});
  @override
  State<WordLearningPage> createState() => _WordLearningPageState();
}

class _WordLearningPageState extends State<WordLearningPage> {
  List<Word> _batch = [];
  int _idx = 0;
  bool _isLoading = true;
  StudyProgress? _progress;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _progress = await DatabaseHelper.instance.getStudyProgress(GlobalData.currentBook);
    _loadBatch(_progress!.currentGroup);
  }

  void _loadBatch(int groupIndex) async {
    setState(() => _isLoading = true);
    List<Word> newWords = await DatabaseHelper.instance.getUnlearnedWords(GlobalData.currentBook, limit: 20);
    if (mounted) {
      setState(() {
        _batch = newWords;
        _idx = 0;
        _isLoading = false;
        _progress!.currentGroup = groupIndex;
      });
    }
  }

  void _handle(bool known) async {
    if (_idx >= _batch.length) return;
    await DatabaseHelper.instance.markWordAsLearned(_batch[_idx].id!);
    if (known) await GlobalData.refreshTodayCount();
    
    if (_idx < _batch.length - 1) {
      setState(() => _idx++);
    } else {
      _progress!.lastReviewTime = DateTime.now();
      await DatabaseHelper.instance.saveStudyProgress(_progress!);
      if (mounted) _showFinishDialog();
    }
  }

  void _showFinishDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("🎉 本组完成"),
        content: const Text("太棒了！休息一下还是继续？"),
        actions: [
          TextButton(child: const Text("再复习一遍"), onPressed: () { Navigator.pop(c); setState(() { _idx = 0; }); }),
          ElevatedButton(child: const Text("下一组"), onPressed: () { Navigator.pop(c); _progress!.currentGroup++; _loadBatch(_progress!.currentGroup); }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.lime)));
    if (_batch.isEmpty) return Scaffold(appBar: AppBar(), body: const Center(child: Text("本书完！")));

    final word = _batch[_idx];
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: AppBar(title: Text("进度: ${_idx + 1}/${_batch.length}")),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_idx + 1) / _batch.length, color: Colors.lime, backgroundColor: Colors.white),
            const Spacer(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), boxShadow: [BoxShadow(color: Colors.teal.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 15))]),
              child: Column(
                children: [
                  Text(word.word, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal[900], fontFamily: 'Georgia')),
                  if (word.phonetic.isNotEmpty) Text("/${word.phonetic}/", style: TextStyle(fontSize: 20, color: Colors.lime[700])),
                  const SizedBox(height: 30),
                  Text(word.definition, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey[600], height: 1.5)),
                ],
              ),
            ),
            const Spacer(flex: 2),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _btn(Icons.close, Colors.red[50]!, Colors.red[300]!, "忘记", () => _handle(false)),
              _btn(Icons.check, Colors.lime[100]!, Colors.lime[800]!, "认识", () => _handle(true)),
            ]),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, Color bg, Color fg, String label, VoidCallback tap) {
    return GestureDetector(onTap: tap, child: Column(children: [Container(width: 70, height: 70, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, color: fg, size: 32)), const SizedBox(height: 8), Text(label, style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold))]));
  }
}