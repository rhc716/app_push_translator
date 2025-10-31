import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// ───── 앱 UI ─────
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'X 푸시 로그',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF252526),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF007ACC),
          secondary: Color(0xFF569CD6),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'monospace'),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ───── 홈 화면 ─────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('notification_channel');

  List<Map<String, String>> logs = []; // title, text, time
  bool _hasRequestedPermission = false;
  bool _channelInitialized = false;
  final int maxLogs = 500;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _initNotificationListener();
    _checkAndRequestPermission();
  }

  void _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLogs = prefs.getStringList('logs') ?? [];
    setState(() {
      logs = savedLogs.map((e) {
        final parts = e.split('::'); // title::text::time
        return {
          'title': parts.isNotEmpty ? parts[0] : '',
          'text': parts.length > 1 ? parts[1] : '',
          'time': parts.length > 2 ? parts[2] : '',
        };
      }).toList();
    });
  }

  void _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final strLogs = logs.take(maxLogs).map((e) =>
        '${e['title']}::${e['text']}::${e['time']}').toList();
    await prefs.setStringList('logs', strLogs);
  }

  void _initNotificationListener() {
    if (_channelInitialized) return; // 이미 초기화 됐으면 중복 등록 안함
    _channelInitialized = true;
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationReceived') {
        final data = Map<String, dynamic>.from(call.arguments);
        final title = data['title'] ?? '';
        final text = data['text'] ?? '';
        final time = DateFormat('HH:mm:ss').format(DateTime.now());

        setState(() {
          logs.insert(0, {'title': title, 'text': text, 'time': time});
          if (logs.length > maxLogs) logs.removeRange(maxLogs, logs.length);
        });
        _saveLogs();
      }
    });
  }

  Future<void> _checkAndRequestPermission() async {
    if (_hasRequestedPermission) return;
    _hasRequestedPermission = true;

    try {
      final granted = await platform.invokeMethod('checkPermission');
      if (granted != true) {
        await platform.invokeMethod('openPermissionSettings');
      }
    } catch (e) {
      setState(() => logs.insert(0, {'title': '권한 오류', 'text': '$e', 'time': ''}));
      _saveLogs();
    }
  }

  Future<void> _confirmClearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252526),
        title: const Text('로그 삭제', style: TextStyle(color: Color(0xFFD4D4D4))),
        content: const Text('정말 모든 로그를 삭제하시겠습니까?',
            style: TextStyle(color: Color(0xFFD4D4D4))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF569CD6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007ACC)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => logs.clear());
      _saveLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("X 푸시 로그 (${logs.length}/$maxLogs)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _confirmClearLogs,
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Text("X 푸시를 기다리는 중...",
                  style: TextStyle(color: Color(0xFFD4D4D4))),
            )
          : ListView.separated(
              reverse: true,
              itemCount: logs.length,
              separatorBuilder: (_, __) => const Divider(
                color: Color(0xFF3C3C3C), // 구분선 색
                height: 1,
                thickness: 1,
              ),
              itemBuilder: (_, i) {
                final log = logs[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(
                      '[${log['time']}] ${log['title']}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF569CD6),
                      ),
                    ),
                    subtitle: Text(
                      log['text'] ?? '',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFFD4D4D4),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
