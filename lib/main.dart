import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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

  // Controllers to keep item-relative scroll position when inserting
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

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

  void _log(msg) {
    final time = DateFormat('HH:mm:ss').format(DateTime.now());

    _insertAtTopPreservingScroll({'title': '[LOG]', 'text': msg, 'time': time});
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

        _insertAtTopPreservingScroll({'title': title, 'text': text, 'time': time});
      }

      // 번역 모델 상태 보여주기
      else if (call.method == 'modelStatus') {
        final data = Map<String, dynamic>.from(call.arguments);
        final status = data['status'] ?? 'unknown';
        final error = data['error'] as String?;

        String message;
        switch (status) {
          case 'downloading':
            message = '번역 모델 다운로드 중...';
            break;
          case 'ready':
            message = '번역 준비 완료!';
            break;
          case 'not_ready':
            message = '번역 모델 없음 → 원문 표시';
            break;
          case 'failed':
            message = '모델 다운로드 실패${error != null ? ': $error' : ''}';
            break;
          default:
            message = '번역 상태: $status';
        }
        // 또는 SnackBar로 알림 (원하면 추가)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }

      // TEST LOG
      else if (call.method == 'TEST') {
        final data = Map<String, dynamic>.from(call.arguments);
        final msg = data['msg'] ?? 'unknown';

        _log(msg);
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
        title: Text.rich(
          TextSpan(
            text: "X PUSH 번역 기록 ",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17
            ), // 기본 텍스트 색상
            children: [
              TextSpan(
                text: " [${logs.length}/$maxLogs]", // 괄호 안의 텍스트
                style: const TextStyle(
                  color: Color.fromARGB(255, 105, 170, 224),
                  fontSize: 17
                ), 
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmClearLogs,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: logs.isEmpty
            ? const Center(
                child: Text("X 푸시를 기다리는 중...",
                    style: TextStyle(color: Color(0xFFD4D4D4))),
              )
            : ScrollablePositionedList.separated(
              reverse: true,
              itemCount: logs.length,
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              separatorBuilder: (_, __) => const Divider(
                color: Color(0xFF3C3C3C), // 구분선 색
                height: 1,
                thickness: 1,
              ),
              itemBuilder: (_, i) {
                final log = logs[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: ListTile(
                    title: Text.rich(
                      TextSpan(
                        text: '[${logs.length - i}]', // 인덱스를 가장 왼쪽에 추가
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Color.fromARGB(255, 105, 170, 224),
                          fontSize: 13.5
                        ),
                        children: [
                          TextSpan(
                            text: ' ${log['time']} ',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Color.fromARGB(255, 57, 147, 221),
                              fontSize: 13.5,
                            ),
                            children: [
                              TextSpan(
                                text: '${log['title']}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: Color.fromARGB(255, 145, 112, 206),
                                  fontSize: 13.5,
                                ),
                              ),
                            ]
                          ),
                        ],
                      ),
                    ),
                    subtitle: Text(
                      log['text'] ?? '',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color.fromARGB(255, 4, 170, 67),
                        fontSize: 14.5
                      ),
                    ),
                  ),
                );
              },
            ),
  ),
    );
  }

  /// Insert a log at the top (index 0) while trying to keep the previously
  /// visible item anchored in the viewport. We capture the first visible
  /// item's index and leading fraction, insert, then jump to the same item
  /// (which shifts to index+1 after insertion) with the same alignment.
  void _insertAtTopPreservingScroll(Map<String, String> entry) {
    final positions = _itemPositionsListener.itemPositions.value;
    int anchorIndex = 1;

    if (positions.isNotEmpty) {
      // choose the visible item with the smallest index (closest to start)
      final first = positions.reduce((a, b) => a.index < b.index ? a : b);
      anchorIndex = first.index;
    }

    setState(() {
      logs.insert(0, entry);
      if (logs.length > maxLogs) logs.removeRange(maxLogs, logs.length);
    });
    _saveLogs();

    if (anchorIndex >= 0) {
      // Schedule after frame so the list has updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetIndex = anchorIndex + 1;
        if (_itemScrollController.isAttached) {
          try {
            // Align to start of viewport so the previously visible item
            // remains visible (positioned at the start).
            _itemScrollController.jumpTo(index: targetIndex, alignment: 0.0);
          } catch (e) {
            // ignore failures (out of range, etc.)
          }
        }
      });
    }
  }
}
