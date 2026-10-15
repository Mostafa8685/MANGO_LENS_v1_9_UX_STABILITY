import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProductFinderApp());
}

const Color kBg = Color(0xFF111214);
const Color kPanel = Color(0xFF1B1D21);
const Color kPanel2 = Color(0xFF26292E);
const Color kAccent = Color(0xFFC75000);
const Color kAccent2 = Color(0xFFFFB45B);
const Color kMuted = Color(0xFF969EAA);
const List<String> kModels = <String>[
  'gemini-2.5-flash',
  'gemini-2.5-pro',
  'gemini-2.0-flash',
];

// App-wide preferences are shared with MaterialApp so theme and locale update instantly.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
final ValueNotifier<bool> appEnglish = ValueNotifier<bool>(false);

class ProductFinderApp extends StatelessWidget {
  const ProductFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appThemeMode, appEnglish]),
      builder: (context, _) {
        return MaterialApp(
          title: 'MANGO LENS | Product Intelligence',
          debugShowCheckedModeBanner: false,
          themeMode: appThemeMode.value,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF7F5F2),
            colorScheme: ColorScheme.fromSeed(seedColor: kAccent, brightness: Brightness.light).copyWith(
              primary: kAccent, secondary: const Color(0xFFB95A00), surface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F5F2), foregroundColor: Color(0xFF202124), centerTitle: false, elevation: 0, scrolledUnderElevation: 0),
            inputDecorationTheme: InputDecorationTheme(
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE7E0D8))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kAccent, width: 1.5)),
            ),
            snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF292621), contentTextStyle: const TextStyle(color: Colors.white), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: kBg,
            colorScheme: ColorScheme.fromSeed(seedColor: kAccent, brightness: Brightness.dark, surface: kPanel).copyWith(
              primary: kAccent, secondary: kAccent2, surface: kPanel,
            ),
            appBarTheme: const AppBarTheme(backgroundColor: kBg, foregroundColor: Colors.white, centerTitle: false, elevation: 0, scrolledUnderElevation: 0),
            inputDecorationTheme: InputDecorationTheme(
              filled: true, fillColor: kPanel2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              labelStyle: const TextStyle(color: kMuted), hintStyle: const TextStyle(color: Color(0xFF858D99)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF34373C))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kAccent, width: 1.5)),
            ),
            snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF292B2F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
          home: Directionality(
            textDirection: appEnglish.value ? TextDirection.ltr : TextDirection.rtl,
            child: const ProductFinderHome(),
          ),
        );
      },
    );
  }
}

class ProductFinderHome extends StatefulWidget {
  const ProductFinderHome({super.key});

  @override
  State<ProductFinderHome> createState() => _ProductFinderHomeState();
}

class _ProductFinderHomeState extends State<ProductFinderHome> {
  final ImagePicker _picker = ImagePicker();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final TextEditingController _extraController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _openAiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController(text: 'gemini-2.5-flash');
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _sellController = TextEditingController();
  final TextEditingController _feesController = TextEditingController(text: '0');
  final TextEditingController _shippingController = TextEditingController(text: '0');

  File? _image;
  String _apiKey = '';
  String _openAiKey = '';
  String _apiProvider = 'gemini';
  String _model = 'gemini-2.5-flash';
  DateTime? _cooldownUntil;
  DateTime? _lastRequestAt;
  String _result = '';
  String _market = 'مصر';
  String _currency = 'EGP';
  int _selectedTab = 0;
  Map<String, dynamic>? _reportData;
  List<Map<String, String>> _sources = <Map<String, String>>[];
  String _condition = 'غير محددة';
  String _category = 'تلقائي';
  String _detailLevel = 'سريع';
  bool _busy = false;
  bool _webSearchEnabled = false;
  String _loadingStage = '';
  Timer? _loadingTimer;
  Timer? _revealTimer;
  int _reportRevealStep = 5;
  int _loadingStageIndex = 0;
  String? _error;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  List<String> _favoriteTitles = <String>[];
  List<String> _availableModels = List<String>.from(kModels);
  bool _checkingKey = false;
  int _apiRequestCount = 0;
  int _apiSuccessCount = 0;
  int _apiFailureCount = 0;
  int _cacheHitCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcomeIfNeeded());
  }

  Future<void> _showWelcomeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || prefs.getBool('mango_welcome_seen_v1') == true) return;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.center_focus_strong_rounded, color: kAccent, size: 42),
      title: const Text('أهلًا بيك في MANGO LENS'),
      content: const Text('حلّل المنتجات من الصور، راجع المواصفات والأسعار، واحفظ تقاريرك على جهازك. تحتاج إلى إعداد مفتاح API من الإعدادات لاستخدام التحليل الذكي.', style: TextStyle(height: 1.6)),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('ابدأ الاستخدام'))],
    ));
    await prefs.setBool('mango_welcome_seen_v1', true);
  }

  void _startLoadingStages() {
    _loadingTimer?.cancel();
    _loadingStageIndex = 0;
    final stages = <String>[_t('جاري تجهيز الصورة...', 'Preparing image...'), _t('جاري التعرّف على المنتج...', 'Identifying product...'), _t('جاري مراجعة المواصفات والأسعار...', 'Checking specs and prices...'), _t('جاري تنظيم التقرير النهائي...', 'Organizing final report...')];
    _loadingStage = stages.first;
    _loadingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_busy) return;
      _loadingStageIndex = (_loadingStageIndex + 1) % stages.length;
      setState(() => _loadingStage = stages[_loadingStageIndex]);
    });
  }

  void _stopLoadingStages() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
    _loadingStage = '';
  }

  void _animateReportSections() {
    _revealTimer?.cancel();
    _reportRevealStep = 0;
    var step = 0;
    _revealTimer = Timer.periodic(const Duration(milliseconds: 220), (timer) {
      if (!mounted) { timer.cancel(); return; }
      step++;
      setState(() => _reportRevealStep = step);
      if (step >= 5) { timer.cancel(); _revealTimer = null; }
    });
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') || lower.contains('failed host lookup') || lower.contains('network is unreachable')) return _t('مفيش اتصال بالإنترنت. راجع الشبكة واضغط إعادة المحاولة.', 'No internet connection. Check your network and retry.');
    if (lower.contains('429') || lower.contains('rate limit') || lower.contains('quota')) return _t('وصلت لحد الاستخدام المؤقت أو الحصة المتاحة. انتظر قليلًا ثم أعد المحاولة.', 'The usage limit or quota was reached. Wait, then retry.');
    if (lower.contains('401') || lower.contains('403') || lower.contains('api key') || lower.contains('مفتاح api')) return _t('مفتاح API غير صحيح أو لا يملك الصلاحية المطلوبة. راجع الإعدادات.', 'The API key is invalid or lacks permission. Check Settings.');
    if (lower.contains('404') || lower.contains('لم يتم العثور على النموذج')) return _t('النموذج المحدد غير متاح. راجع اسم النموذج من الإعدادات.', 'The selected model was not found. Check its ID in Settings.');
    if (lower.contains('format') || lower.contains('json') || lower.contains('رد غير مفهوم')) return _t('الخدمة أرسلت ردًا غير متوقع. جرّب مرة أخرى أو استخدم صورة أوضح.', 'The service returned an unexpected response. Retry or use a clearer image.');
    return raw.isEmpty ? _t('حصل خطأ غير متوقع. حاول مرة أخرى.', 'Something went wrong. Please retry.') : raw;
  }

  Future<void> _showPrivacy() async {
    final title = _t('الخصوصية والبيانات', 'Privacy & data');
    final body = _t(
      '• الصور التي تختار تحليلها تُرسل إلى مزود الذكاء الاصطناعي المحدد لإنتاج التقرير.\n\n• سجل التقارير والمفضلة والإعدادات تُحفظ محليًا على هذا الجهاز باستخدام تخزين التطبيق.\n\n• مفتاح API يُخزّن في التخزين الآمن على الجهاز، لكن أي مفتاح داخل تطبيق موزّع لا يُعد محميًا بالكامل؛ النسخة التجارية العامة تحتاج خادمًا وسيطًا.\n\n• التطبيق لا يضمن دقة الأسعار أو تقديرات الندرة؛ راجع المصادر وتاريخ التحقق قبل الشراء أو البيع.\n\n• حذف بيانات التطبيق من إعدادات Android قد يؤدي إلى حذف السجل والإعدادات المحلية.',
      '• Images you choose to analyze are sent to the selected AI provider to generate the report.\n\n• Report history, favorites, and settings are stored locally on this device.\n\n• API keys use device secure storage, but no key embedded in a distributed app is fully protected; a public commercial release needs a backend proxy.\n\n• Prices and rarity estimates are not guaranteed; verify sources and dates before buying or selling.\n\n• Clearing app data in Android settings may remove local history and settings.');
    await Navigator.push<void>(context, MaterialPageRoute(builder: (ctx) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.privacy_tip_outlined, color: kAccent, size: 48),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        _surfaceCard(child: Text(body, style: const TextStyle(height: 1.8, fontSize: 14))),
        const SizedBox(height: 12),
        Text(_t('آخر تحديث: 15 أكتوبر 2026', 'Last updated: October 15, 2026'), style: TextStyle(color: _mutedColor, fontSize: 11)),
      ])),
    )));
  }

  Future<void> _showAbout() async {
    final title = _t('عن التطبيق', 'About this app');
    await Navigator.push<void>(context, MaterialPageRoute(builder: (ctx) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        Container(width: 76, height: 76, alignment: Alignment.center, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF9A38), Color(0xFFE75D00)]), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 42)),
        const SizedBox(height: 18),
        const Text('MANGO LENS', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(_t('الإصدار 1.9.0 (Build 10)', 'Version 1.9.0 (Build 10)'), style: const TextStyle(color: kAccent, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _surfaceCard(child: Text(_t('من تطوير شركة مانجو\nالمؤسس: مصطفى ماجد\n\nتطبيق مساعد للتعرّف على المنتجات من الصور، وتنظيم معلوماتها ومقارنة الأسعار وتقدير الندرة. النتائج إرشادية وقد لا تكون دقيقة أو محدثة دائمًا؛ تحقّق من المصادر قبل اتخاذ قرار شراء أو بيع.', 'Made by MANGO Company\nFounder: Mostafa Maged\n\nAn assistant for identifying products from images, organizing details, comparing prices, and estimating rarity. Results are informational and may not always be accurate or current; verify sources before buying or selling.'), style: const TextStyle(height: 1.8))),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _showPrivacy, icon: const Icon(Icons.privacy_tip_outlined), label: Text(_t('قراءة سياسة الخصوصية', 'Read privacy information'))),
      ])),
    )));
  }

  @override
  void dispose() {
    _extraController.dispose();
    _keyController.dispose();
    _openAiKeyController.dispose();
    _modelController.dispose();
    _costController.dispose();
    _sellController.dispose();
    _feesController.dispose();
    _shippingController.dispose();
    _loadingTimer?.cancel();
    _revealTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Migrate legacy plaintext keys to Android Keystore-backed secure storage.
    String geminiKey = '';
    String openAiKey = '';
    try {
      geminiKey = await _secureStorage.read(key: 'gemini_api_key') ?? '';
      openAiKey = await _secureStorage.read(key: 'openai_api_key') ?? '';
      if (geminiKey.isEmpty) {
        final legacy = prefs.getString('gemini_api_key') ?? '';
        if (legacy.isNotEmpty) {
          await _secureStorage.write(key: 'gemini_api_key', value: legacy);
          geminiKey = legacy;
          await prefs.remove('gemini_api_key');
        }
      }
      if (openAiKey.isEmpty) {
        final legacy = prefs.getString('openai_api_key') ?? '';
        if (legacy.isNotEmpty) {
          await _secureStorage.write(key: 'openai_api_key', value: legacy);
          openAiKey = legacy;
          await prefs.remove('openai_api_key');
        }
      }
    } catch (_) {
      // Keep the app usable if device secure storage is unavailable. Legacy values
      // are read as a last resort, but are not written back in plaintext.
      geminiKey = geminiKey.isNotEmpty ? geminiKey : (prefs.getString('gemini_api_key') ?? '');
      openAiKey = openAiKey.isNotEmpty ? openAiKey : (prefs.getString('openai_api_key') ?? '');
    }
    List<Map<String, dynamic>> history = <Map<String, dynamic>>[];
    try {
      final raw = prefs.getString('product_history_v2');
      if (raw != null) {
        history = (jsonDecode(raw) as List<dynamic>)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      history = <Map<String, dynamic>>[];
    }
    List<String> favorites = <String>[];
    try { favorites = prefs.getStringList('mango_favorite_titles') ?? <String>[]; } catch (_) {}
    final initializedV16Search = prefs.getBool('mango_v16_search_default_initialized') ?? false;
    if (!initializedV16Search) {
      await prefs.setBool('mango_web_search_enabled', true);
      await prefs.setBool('mango_v16_search_default_initialized', true);
    }
    if (!mounted) return;
    setState(() {
      _favoriteTitles = favorites;
      _apiKey = geminiKey;
      _openAiKey = openAiKey;
      _apiProvider = prefs.getString('ai_provider') ?? 'gemini';
      _model = prefs.getString(_apiProvider == 'openai' ? 'openai_model' : 'gemini_model') ?? (_apiProvider == 'openai' ? 'gpt-4.1-mini' : 'gemini-2.5-flash');
      final lastMs = prefs.getInt('mango_last_api_request_ms');
      if (lastMs != null) _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(lastMs);
      final cooldownMs = prefs.getInt('mango_api_cooldown_until_ms');
      if (cooldownMs != null && cooldownMs > DateTime.now().millisecondsSinceEpoch) _cooldownUntil = DateTime.fromMillisecondsSinceEpoch(cooldownMs);
      _modelController.text = _model;
      _market = prefs.getString('product_market') ?? 'مصر';
      _currency = prefs.getString('product_currency') ?? 'EGP';
      _condition = prefs.getString('product_condition') ?? 'غير محددة';
      _category = prefs.getString('product_category') ?? 'تلقائي';
      _detailLevel = prefs.getString('product_detail') ?? 'سريع';
      _webSearchEnabled = initializedV16Search ? (prefs.getBool('mango_web_search_enabled') ?? true) : true;
      _history = history;
      _apiRequestCount = prefs.getInt('mango_api_request_count') ?? 0;
      _apiSuccessCount = prefs.getInt('mango_api_success_count') ?? 0;
      _apiFailureCount = prefs.getInt('mango_api_failure_count') ?? 0;
      _cacheHitCount = prefs.getInt('mango_api_cache_hit_count') ?? 0;
      appThemeMode.value = (prefs.getString('app_theme_mode') ?? 'dark') == 'light' ? ThemeMode.light : ThemeMode.dark;
      appEnglish.value = prefs.getBool('app_english') ?? false;
    });
  }

  String _t(String ar, String en) => appEnglish.value ? en : ar;

  Future<String> _checkApiKey(String key) async {
    if (key.trim().isEmpty) return _t('اكتب مفتاح API أولًا.', 'Enter an API key first.');
    try {
      // Listing models does not run a generation, so it avoids spending generation tokens.
      final response = await http.get(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?pageSize=100'),
        headers: <String, String>{'x-goog-api-key': key.trim()},
      ).timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final err = data['error'];
        final message = err is Map ? (err['message']?.toString() ?? 'Unknown API error') : 'Unknown API error';
        if (response.statusCode == 429) {
          return '${_t('مفتاح API وصل إلى حد الطلبات عند اختبار قائمة النماذج. ده مش استهلاك تحليل من التطبيق؛ راجع المشروع والحصة في AI Studio.', 'The API key/project is rate-limited even for the model-list request. Check the project and quota in AI Studio.')}\n$message';
        }
        return '${_t('فشل الاختبار', 'Test failed')} (${response.statusCode}): $message';
      }
      final models = <String>[];
      final rawModels = data['models'];
      if (rawModels is List) {
        for (final item in rawModels) {
          if (item is! Map) continue;
          final methods = item['supportedGenerationMethods'];
          final name = item['name']?.toString().replaceFirst('models/', '') ?? '';
          if (name.isNotEmpty && methods is List && methods.contains('generateContent')) models.add(name);
        }
      }
      models.sort();
      if (models.isNotEmpty && mounted) setState(() => _availableModels = models);
      return _t('الاتصال ناجح. تم العثور على ${models.length} نموذجًا يدعم generateContent. لم يتم إنشاء تحليل ولم تُستهلك رموز توليد.', 'Connection successful. Found ${models.length} models supporting generateContent. No analysis was generated and no generation tokens were spent.');
    } on SocketException {
      return _t('تعذر الاتصال بالإنترنت. تحقق من الشبكة.', 'Could not connect. Check your internet connection.');
    } on FormatException {
      return _t('رد الخدمة غير مفهوم.', 'The service returned an unreadable response.');
    } catch (e) {
      return '${_t('تعذر إكمال الاختبار', 'Could not complete the test')}: $e';
    }
  }

  Future<String> _checkOpenAiKey(String key) async {
    if (key.trim().isEmpty) return _t('اكتب مفتاح OpenAI API أولًا.', 'Enter an OpenAI API key first.');
    try {
      final response = await http.get(Uri.parse('https://api.openai.com/v1/models'), headers: {'Authorization': 'Bearer ${key.trim()}'}).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = response.body;
        try { final decoded = jsonDecode(response.body); if (decoded is Map && decoded['error'] is Map) message = (decoded['error'] as Map)['message']?.toString() ?? message; } catch (_) {}
        return '${_t('فشل اختبار OpenAI', 'OpenAI test failed')} (${response.statusCode}): $message';
      }
      return _t('اتصال OpenAI ناجح. لم يتم إنشاء تحليل.', 'OpenAI connection successful. No analysis was generated.');
    } on SocketException { return _t('تعذر الاتصال بالإنترنت.', 'Could not connect to the internet.'); }
    catch (e) { return '${_t('تعذر إكمال الاختبار', 'Could not complete test')}: $e'; }
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) { hash ^= unit; hash = (hash * 0x01000193) & 0x7fffffff; }
    return hash;
  }

  Future<http.Response> _sendGeminiRequest(String prompt, List<int> bytes) {
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${Uri.encodeComponent(_model)}:generateContent');
    return http.post(uri,
      headers: <String, String>{'Content-Type': 'application/json', 'x-goog-api-key': _apiKey},
      body: jsonEncode(<String, dynamic>{
        'contents': <dynamic>[{'parts': <dynamic>[{'text': prompt}, {'inline_data': {'mime_type': _mimeFor(_image!.path), 'data': base64Encode(bytes)}}]}],
        if (_webSearchEnabled) 'tools': <dynamic>[{'google_search': <String, dynamic>{}}],
        'generationConfig': <String, dynamic>{'temperature': _detailLevel == 'سريع' ? 0.2 : 0.3, 'maxOutputTokens': _detailLevel == 'سريع' ? 1100 : 2400},
      }),
    ).timeout(const Duration(seconds: 150));
  }

  Future<http.Response> _sendOpenAiRequest(String prompt, List<int> bytes) {
    final imageData = 'data:${_mimeFor(_image!.path)};base64,${base64Encode(bytes)}';
    return http.post(Uri.parse('https://api.openai.com/v1/responses'),
      headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $_openAiKey'},
      body: jsonEncode(<String, dynamic>{
        'model': _model,
        if (_webSearchEnabled) 'tools': <dynamic>[{'type': 'web_search', 'search_context_size': 'low'}],
        if (_webSearchEnabled) 'tool_choice': 'required',
        'input': <dynamic>[{'role': 'user', 'content': <dynamic>[{'type': 'input_text', 'text': prompt}, {'type': 'input_image', 'image_url': imageData, 'detail': 'auto'}]}],
        'max_output_tokens': _detailLevel == 'سريع' ? 1100 : 2400,
      }),
    ).timeout(const Duration(seconds: 150));
  }

  String _openAiReport(Map<String, dynamic> data) {
    final direct = data['output_text']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final out = StringBuffer();
    final output = data['output'];
    if (output is List) {
      for (final item in output) {
        if (item is! Map || item['content'] is! List) continue;
        for (final part in item['content'] as List) {
          if (part is Map && part['type'] == 'output_text') {
            final t = part['text']?.toString() ?? '';
            if (t.isNotEmpty) out.writeln(t);
          }
        }
      }
    }
    return out.toString().trim();
  }

  List<Map<String, String>> _openAiSources(Map<String, dynamic> data) {
    final sources = <Map<String, String>>[]; final seen = <String>{}; final output = data['output'];
    if (output is! List) return sources;
    for (final item in output) { if (item is! Map || item['content'] is! List) continue;
      for (final part in item['content'] as List) { if (part is! Map || part['annotations'] is! List) continue;
        for (final a in part['annotations'] as List) { if (a is! Map || a['type'] != 'url_citation') continue;
          final u = a['url']?.toString() ?? ''; final parsed = Uri.tryParse(u);
          if (parsed != null && (parsed.scheme == 'https' || parsed.scheme == 'http') && seen.add(u)) sources.add({'title': a['title']?.toString() ?? parsed.host, 'url': u});
        }
      }
    }
    return sources;
  }

  Future<void> _settings() async {
    _keyController.text = _apiKey;
    _openAiKeyController.text = _openAiKey;
    _modelController.text = _model;
    String selectedProvider = _apiProvider;
    bool showKey = false;
    String chosenModel = (_availableModels.contains(_model) || kModels.contains(_model)) ? _model : 'أدخل اسمًا مخصصًا';
    String? testResult;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refreshDialog) => AlertDialog(
          backgroundColor: appThemeMode.value == ThemeMode.light ? Colors.white : kPanel,
          title: Row(children: [
            const Icon(Icons.tune_rounded, color: kAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(_t('إعدادات الذكاء الاصطناعي', 'AI settings'))),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('اختَر مزود الذكاء الاصطناعي واكتب معرّف النموذج يدويًا. تقرير المنتج والبحث المدمج يُطلبان معًا في استدعاء تحليل واحد.', 'Choose a provider and type the model ID manually; you can update it later without updating the app.'), style: const TextStyle(color: kMuted, height: 1.5)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedProvider,
                isExpanded: true,
                decoration: InputDecoration(labelText: _t('مزود الذكاء الاصطناعي', 'AI provider')),
                items: const [DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')), DropdownMenuItem(value: 'openai', child: Text('OpenAI API'))],
                onChanged: (value) {
                  if (value == null) return;
                  refreshDialog(() {
                    selectedProvider = value;
                    _modelController.text = value == 'openai' ? 'gpt-4.1-mini' : 'gemini-2.5-flash';
                    chosenModel = 'أدخل اسمًا مخصصًا';
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyController,
                obscureText: !showKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(tooltip: showKey ? 'إخفاء المفتاح' : 'إظهار المفتاح', onPressed: () => refreshDialog(() => showKey = !showKey), icon: Icon(showKey ? Icons.visibility_off : Icons.visibility)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _openAiKeyController,
                obscureText: !showKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: 'OpenAI API Key', prefixIcon: const Icon(Icons.key_outlined), hintText: 'sk-…'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: chosenModel,
                isExpanded: true,
                decoration: InputDecoration(labelText: _t('نموذج جاهز', 'Available model')),
                items: <String>{..._availableModels, ...kModels, 'أدخل اسمًا مخصصًا'}.toList().map((m) => DropdownMenuItem<String>(value: m, child: Text(m))).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  refreshDialog(() {
                    chosenModel = value;
                    if (value != 'أدخل اسمًا مخصصًا') _modelController.text = value;
                    else _modelController.clear();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelController,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: _t('اسم النموذج المستخدم فعليًا', 'Model ID to use'),
                  hintText: selectedProvider == 'openai' ? 'gpt-4.1-mini' : 'gemini-2.5-flash',
                  prefixIcon: Icon(Icons.memory_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: appThemeMode.value == ThemeMode.light ? const Color(0xFFFFF2E5) : kPanel2, borderRadius: BorderRadius.circular(14)),
                child: const Text(
                  'أدخل مفتاح المزود الذي اخترته. المفاتيح محفوظة محليًا لهذا الجهاز فقط، وده مناسب للتجربة الشخصية؛ إصدار عام لشركة مانجو يحتاج خادمًا وسيطًا يحمي المفاتيح ويحدد استهلاك كل مستخدم.',
                  style: TextStyle(color: kMuted, fontSize: 12, height: 1.6),
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 6),
              const Divider(),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(_t('الوضع الداكن', 'Dark theme')),
                subtitle: Text(_t('أوقفه لاستخدام الوضع الفاتح', 'Turn off to use light theme')),
                value: appThemeMode.value == ThemeMode.dark,
                onChanged: (value) async {
                  appThemeMode.value = value ? ThemeMode.dark : ThemeMode.light;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('app_theme_mode', value ? 'dark' : 'light');
                  refreshDialog(() {});
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.language_rounded),
                title: Text(_t('اللغة الإنجليزية', 'English language')),
                subtitle: Text(_t('العربية هي اللغة الأساسية', 'Arabic is the default language')),
                value: appEnglish.value,
                onChanged: (value) async {
                  appEnglish.value = value;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('app_english', value);
                  refreshDialog(() {});
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _checkingKey ? null : () async {
                  refreshDialog(() { _checkingKey = true; testResult = null; });
                  final result = selectedProvider == 'gemini' ? await _checkApiKey(_keyController.text) : await _checkOpenAiKey(_openAiKeyController.text);
                  if (!ctx.mounted) return;
                  refreshDialog(() {
                    _checkingKey = false;
                    testResult = result;
                    if (selectedProvider == 'gemini' && _availableModels.isNotEmpty && !_availableModels.contains(_modelController.text.trim())) {
                      _modelController.text = _availableModels.first;
                      chosenModel = _availableModels.first;
                    }
                  });
                },
                icon: _checkingKey ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.network_check_rounded),
                label: Text(_checkingKey ? _t('جاري اختبار الاتصال...', 'Testing connection...') : _t('اختبار الاتصال', 'Test connection')),
              ),
              if (testResult != null) ...[
                const SizedBox(height: 8),
                Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: appThemeMode.value == ThemeMode.light ? const Color(0xFFF0F2F8) : kPanel2, borderRadius: BorderRadius.circular(12)), child: Text(testResult!, style: const TextStyle(fontSize: 12, height: 1.5))),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: appThemeMode.value == ThemeMode.light ? const Color(0xFFF0F2F8) : kPanel2, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_t('عن التطبيق', 'About this app'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(_t('صناعة شركة مانجو', 'Made by MANGO Company'), style: const TextStyle(fontSize: 13)),
                  Text(_t('المؤسس: مصطفى ماجد', 'Founder: Mostafa Maged'), style: const TextStyle(color: kMuted, fontSize: 12)),
                  Text('MANGO LENS • v1.9.0', style: const TextStyle(color: kMuted, fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                OutlinedButton.icon(onPressed: _showPrivacy, icon: const Icon(Icons.privacy_tip_outlined), label: Text(_t('الخصوصية', 'Privacy'))),
                OutlinedButton.icon(onPressed: _showAbout, icon: const Icon(Icons.info_outline_rounded), label: Text(_t('عن التطبيق والإصدار', 'About & version'))),
              ]),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _openUrl(selectedProvider == 'openai' ? 'https://platform.openai.com/api-keys' : 'https://aistudio.google.com/apikey'),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(selectedProvider == 'openai' ? _t('فتح منصة OpenAI', 'Open OpenAI platform') : _t('فتح Google AI Studio', 'Open Google AI Studio')),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('إلغاء', 'Cancel'))),
            FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.save_outlined), label: Text(_t('حفظ', 'Save'))),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final key = _keyController.text.trim();
    final openAiKey = _openAiKeyController.text.trim();
    final model = _modelController.text.trim().replaceAll('models/', '');
    if (model.isEmpty) {
      _message('اكتب معرّف النموذج أولًا');
      return;
    }
    if (selectedProvider == 'gemini' && key.isEmpty) { _message('أدخل مفتاح Gemini API'); return; }
    if (selectedProvider == 'openai' && openAiKey.isEmpty) { _message('أدخل مفتاح OpenAI API'); return; }
    final prefs = await SharedPreferences.getInstance();
    // Store provider credentials in encrypted platform storage, not plain preferences.
    await _secureStorage.write(key: 'gemini_api_key', value: key);
    await _secureStorage.write(key: 'openai_api_key', value: openAiKey);
    await prefs.remove('gemini_api_key');
    await prefs.remove('openai_api_key');
    await prefs.setString('ai_provider', selectedProvider);
    await prefs.setString(selectedProvider == 'openai' ? 'openai_model' : 'gemini_model', model);
    if (!mounted) return;
    setState(() {
      _apiKey = key;
      _openAiKey = openAiKey;
      _apiProvider = selectedProvider;
      _model = model;
    });
    _message('تم حفظ الإعدادات');
  }

  Future<void> _chooseImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 74,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _result = '';
        _reportData = null;
        _sources = <Map<String, String>>[];
        _error = null;
      });
    } catch (_) {
      _message('تعذر فتح الكاميرا أو الصور. تأكد من أذونات الجهاز ثم حاول مرة أخرى.');
    }
  }

  void _imageOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: appThemeMode.value == ThemeMode.light ? Colors.white : kPanel,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(children: [
            const ListTile(title: Text('اختر صورة المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFFE1C4), child: Icon(Icons.camera_alt_rounded, color: Color(0xFFE75D00))),
              title: const Text('التقاط صورة بالكاميرا'),
              subtitle: const Text('صوّر المنتج والملصق بوضوح'),
              onTap: () { Navigator.pop(ctx); _chooseImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF163D3A), child: Icon(Icons.photo_library_outlined, color: kAccent2)),
              title: const Text('اختيار صورة من المعرض'),
              subtitle: const Text('يمكن اختيار صورة ملتقطة سابقًا'),
              onTap: () { Navigator.pop(ctx); _chooseImage(ImageSource.gallery); },
            ),
          ]),
        ),
      ),
    );
  }

  String _mimeFor(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _makePrompt(String extra) {
    final answerLanguage = appEnglish.value ? 'clear English' : 'العربية الواضحة';
    final detail = _detailLevel == 'سريع'
        ? 'اختصر الشرح فقط؛ احتفظ بهوية المنتج والسعر والعروض وروابط المصادر ومؤشرات الندرة.'
        : 'أنشئ تقريرًا غنيًا بالمعلومات، لكن اجمع كل العمل في هذا الاستدعاء الواحد ولا تطلب استدعاءً آخر.';
    final currencyName = switch (_currency) {
      'USD' => 'US dollars (USD)',
      'SAR' => 'Saudi riyals (SAR)',
      'EUR' => 'euros (EUR)',
      _ => 'Egyptian pounds (EGP)',
    };
    return '''أنت MANGO LENS، مساعد احترافي للتعرف على المنتجات ومقارنة أسعارها.
المطلوب: نفّذ تحليل الصورة والبحث على الويب وتجميع المعلومات والتقرير في استدعاء API واحد فقط. لا تقترح أو تنفذ خطوات إضافية ولا تطلب استدعاءات مستقلة.
${_webSearchEnabled ? 'استخدم أداة Google Search المتاحة داخل هذا الطلب للعثور على عروض حديثة، وخصوصًا في سوق $_market. ابحث عن صفحة المنتج المباشرة في Amazon.eg إذا كان السوق مصر وكان المنتج موجودًا. استخدم الروابط التي تُرجعها نتائج البحث فقط.' : 'البحث المباشر مغلق. لا تدّع أن السعر حالي أو أن رابط متجر تم التحقق منه؛ اذكر أن السعر تقديري وغير متحقق منه.'}

لغة التقرير: $answerLanguage.
سوق البحث: $_market.
عملة التقرير المطلوبة: $currencyName.
حالة المنتج: $_condition.
التصنيف المفضل: $_category.
مستوى التفاصيل: $_detailLevel.
${extra.isNotEmpty ? 'طلبات إضافية من المستخدم: $extra' : ''}

$detail

أخرج JSON صالحًا فقط، من دون Markdown خارجه أو مقدمة. استخدم هذا المخطط بالضبط:
{
  "product_name": "اسم المنتج المختصر إن أمكن",
  "brand": "العلامة التجارية أو غير معروف",
  "model": "رقم الموديل أو غير معروف",
  "product_identity": "كيف تم التعرف على المنتج ودرجة الثقة وما بقي غير مؤكد",
  "description_specifications": "وصف المنتج والمواصفات والخامات والمقاس والسعة واستخداماته؛ ميّز الحقائق عن الاستنتاجات",
  "price_summary": "ملخص السعر الأدنى الموثوق ونطاق الأسعار، بعملة التقرير المطلوبة $currencyName، أو وضح عدم توفر سعر موثوق؛ اذكر وقت التحقق وحداثة البيانات",
  "price_history_note": "هل توجد بيانات تاريخية فعلية موثقة أم لا؛ لا تخترع تاريخًا سابقًا",
  "offers": [
    {"store":"اسم المتجر", "price":"السعر كما يظهر في المصدر", "currency":"رمز عملة السعر الأصلي مثل EGP أو USD", "converted_price":"السعر بالعملة المطلوبة إن أمكن تحويله بسعر صرف موثوق من مصدر بحث؛ وإلا نص فارغ", "condition":"جديد أو مستعمل أو غير واضح", "availability":"متاح أو غير مؤكد أو غير متاح حسب المصدر", "shipping":"الشحن والضرائب إن كانت مذكورة وإلا غير معروف", "url":"رابط العرض المباشر الذي وجدته فعلًا", "checked_at":"وقت أو تاريخ التحقق إذا ظهر في المصدر وإلا غير مذكور"}
  ],
  "amazon_eg_url": "رابط صفحة المنتج على Amazon.eg إذا وجدته فعليًا، وإلا نص فارغ",
  "purchase_links_comparison": "مقارنة العروض والاختلافات، وميّز رابط صفحة المنتج من رابط نتائج البحث",
  "rarity_assessment": "تقييم مدى الشيوع أو الندرة وقيمة الاقتناء، مع توضيح إن كانت الأدلة غير كافية",
  "rarity_score": "تقدير اختياري من 0 إلى 100 أو null إذا لم توجد أدلة كافية؛ لا تقدّم الرقم كحقيقة مؤكدة",
  "confidence_level": "منخفض أو متوسط أو مرتفع مع سبب مختصر",
  "rarity_signals": [
    {"signal":"مؤشر الندرة أو الشيوع", "evidence":"الدليل المتاح أو نقص الدليل", "assessment":"تأثير المؤشر ودرجة الثقة"}
  ],
  "authenticity_condition": "ما يظهر عن الحالة وعلامات الأصالة الممكن فحصها؛ لا تؤكد الأصالة نهائيًا من صورة واحدة",
  "buying_tips": "نصائح الشراء وما يلزم التحقق منه",
  "quick_summary": "خلاصة سريعة للاسم والسعر ودرجة الثقة والخطوة التالية"
}

قواعد صارمة:
- أعد JSON صالحًا فقط، واحرص أن يكون offers وrarity_signals مصفوفتين حتى لو كانتا فارغتين []. لا تخترع نتائج أو روابط أو أرقام أسعار.
- اجعل الأسعار في ملخص التقرير بعملة $currencyName عندما يوجد سعر موثوق. إذا كان السعر الأصلي بعملة أخرى، احتفظ به كما ظهر بالمصدر، ولا تملأ converted_price إلا إذا توفر سعر صرف موثوق من نتيجة البحث؛ لا تخمّن التحويل.
- للبحث في مصر، ضع في amazon_eg_url رابط صفحة المنتج الفعلية على Amazon.eg فقط إذا عُثر عليها. لا تضع رابط بحث مكان صفحة منتج مباشرة.
- لا تختلق المخزون أو تاريخ التحقق أو الضريبة أو تكلفة الشحن. لا تخلط بين سعر جديد وسعر مستعمل.
- الندرة ليست حقيقة يمكن إثباتها من مظهر الصورة وحده؛ اربط الحكم بأدلة الإصدار المحدود أو بيانات السوق، وإلا قل إن الندرة غير مؤكدة. لا تمنح درجة ندرة رقمية إلا مع توضيح محدودية الأدلة.
- لا تدّع وجود سجل تاريخي للأسعار إلا إذا توفر سجل فعلي؛ إذا لم تتوفر بيانات سابقة فقل ذلك بوضوح.
- اذكر وقت التحقق الفعلي عند توفره، ولا تخترع توقيتًا أو توافرًا أو أسعارًا.
- إذا تعذر التعرف على المنتج، صرّح بذلك واقترح تصوير ملصق الموديل أو الرقم التسلسلي بوضوح.
''';
  }

  Map<String, dynamic>? _decodeReportObject(String raw) {
    var candidate = raw.trim();
    if (candidate.startsWith('```')) {
      candidate = candidate.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
      candidate = candidate.replaceFirst(RegExp(r'\s*```$'), '').trim();
    }
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Some custom model IDs may add a short preface despite the JSON-only instruction.
      final firstBrace = candidate.indexOf('{');
      final lastBrace = candidate.lastIndexOf('}');
      if (firstBrace >= 0 && lastBrace > firstBrace) {
        try {
          final decoded = jsonDecode(candidate.substring(firstBrace, lastBrace + 1));
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
    }
    return null;
  }

  String _valueText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) return value.map(_valueText).where((v) => v.isNotEmpty).join('\n');
    return value.toString().trim();
  }

  String _normalizeReport(String raw) {
    final decoded = _decodeReportObject(raw);
    if (decoded == null) return raw.trim();
    final sections = <String, String>{
      'product_identity': '1. تحديد هوية المنتج',
      'description_specifications': '2. الوصف والمواصفات',
      'price_summary': '3. ملخص الأسعار',
      'price_history_note': 'سجل تغيّر الأسعار',
      'purchase_links_comparison': '4. روابط الشراء والمقارنة',
      'rarity_assessment': '5. الندرة والقيمة لهواة الاقتناء',
      'rarity_score': 'درجة الندرة التقديرية',
      'confidence_level': 'مستوى الثقة',
      'authenticity_condition': '6. الأصالة والحالة',
      'buying_tips': '7. نصائح قبل الشراء',
      'quick_summary': '8. الخلاصة السريعة',
    };
    final out = StringBuffer();
    final name = _valueText(decoded['product_name']);
    final brand = _valueText(decoded['brand']);
    final model = _valueText(decoded['model']);
    if (name.isNotEmpty || brand.isNotEmpty || model.isNotEmpty) {
      out.writeln('## المنتج');
      if (name.isNotEmpty) out.writeln('**الاسم:** $name');
      if (brand.isNotEmpty) out.writeln('**العلامة التجارية:** $brand');
      if (model.isNotEmpty) out.writeln('**الموديل:** $model');
      out.writeln();
    }
    for (final entry in sections.entries) {
      final value = _valueText(decoded[entry.key]);
      if (value.isEmpty || value == 'null') continue;
      out.writeln('## ${entry.value}\n$value\n');
    }
    final offers = decoded['offers'];
    if (offers is List && offers.isNotEmpty) {
      out.writeln('## عروض الأسعار');
      out.writeln('| المتجر | السعر الأصلي | السعر بعملة التقرير | الحالة | الرابط |');
      out.writeln('|---|---:|---:|---|---|');
      for (final item in offers.whereType<Map>()) {
        final store = _valueText(item['store']).replaceAll('|', '\\|');
        final price = '${_valueText(item['price'])} ${_valueText(item['currency'])}'.trim().replaceAll('|', '\\|');
        final converted = _valueText(item['converted_price']).replaceAll('|', '\\|');
        final condition = _valueText(item['condition']).replaceAll('|', '\\|');
        final url = _valueText(item['url']);
        final link = Uri.tryParse(url) != null && (url.startsWith('https://') || url.startsWith('http://')) ? '[فتح العرض]($url)' : 'غير متوفر';
        out.writeln('| $store | $price | ${converted.isEmpty ? 'غير متاح' : converted} | $condition | $link |');
      }
      out.writeln();
    }
    final rarityRows = decoded['rarity_signals'];
    if (rarityRows is List && rarityRows.isNotEmpty) {
      out.writeln('## مؤشرات الندرة');
      out.writeln('| المؤشر | الدليل | التقييم |');
      out.writeln('|---|---|---|');
      for (final item in rarityRows.whereType<Map>()) {
        out.writeln('| ${_valueText(item['signal']).replaceAll('|', '\\|')} | ${_valueText(item['evidence']).replaceAll('|', '\\|')} | ${_valueText(item['assessment']).replaceAll('|', '\\|')} |');
      }
      out.writeln();
    }
    final amazonUrl = _valueText(decoded['amazon_eg_url']);
    if (amazonUrl.isNotEmpty) out.writeln('**Amazon.eg:** [$amazonUrl]($amazonUrl)\n');
    return out.toString().trim().isEmpty ? raw.trim() : out.toString().trim();
  }

  String _normalizeLegacyReport(String raw) {
    var candidate = raw.trim();
    if (candidate.startsWith('```')) {
      candidate = candidate.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
      candidate = candidate.replaceFirst(RegExp(r'\s*```$'), '').trim();
    }
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is! Map) return raw.trim();
      const sections = <String, String>{
        'product_identity': '1. تحديد هوية المنتج',
        'description_specifications': '2. الوصف والمواصفات',
        'prices_and_offers': '3. الأسعار والعروض',
        'purchase_links_comparison': '4. روابط الشراء والمقارنة',
        'rarity_collectible_value': '5. الندرة والقيمة لهواة الاقتناء',
        'authenticity_condition': '6. الأصالة والحالة',
        'buying_tips': '7. نصائح قبل الشراء',
        'quick_summary': '8. الخلاصة السريعة',
      };
      final out = StringBuffer();
      for (final entry in sections.entries) {
        final value = decoded[entry.key]?.toString().trim() ?? '';
        if (value.isEmpty || value == 'null') continue;
        if (out.isNotEmpty) out.writeln('\n');
        out.writeln('## ${entry.value}');
        out.writeln(value);
      }
      return out.toString().trim().isEmpty ? raw.trim() : out.toString().trim();
    } catch (_) {
      return raw.trim();
    }
  }

  String _extractSection(String heading) {
    if (_result.trim().isEmpty) return '';
    final lines = _result.split('\n');
    final out = <String>[];
    var reading = false;
    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (reading) break;
        reading = line.substring(3).trim().toLowerCase().contains(heading.toLowerCase());
        continue;
      }
      if (reading) out.add(line);
    }
    return out.join('\n').trim();
  }

  String _currencyLabel() => switch (_currency) {
    'USD' => _t('دولار أمريكي (USD)', 'US Dollar (USD)'),
    'SAR' => _t('ريال سعودي (SAR)', 'Saudi Riyal (SAR)'),
    'EUR' => _t('يورو (EUR)', 'Euro (EUR)'),
    _ => _t('جنيه مصري (EGP)', 'Egyptian Pound (EGP)'),
  };

  String _currencySymbol(String currency) => switch (currency.toUpperCase()) {
    'USD' => '\$', 'SAR' => 'ر.س', 'EUR' => '€', 'EGP' => 'ج.م', _ => currency,
  };

  String _formatMoney(String amount, String currencyCode) {
    final value = amount.trim();
    if (value.isEmpty) return '';
    final code = currencyCode.toUpperCase();
    final symbol = _currencySymbol(code);
    if (value.toUpperCase().contains(code) || value.contains(symbol) || (code == 'USD' && value.contains(r'$'))) return value;
    return '$value $symbol';
  }

  String _productName() {
    final structuredName = _valueText(_reportData?['product_name']);
    if (structuredName.isNotEmpty && structuredName.toLowerCase() != 'unknown') return structuredName;
    final identity = _valueText(_reportData?['product_identity']);
    if (identity.isNotEmpty) return identity.split('\n').first.replaceAll(RegExp(r'^[#*\-\s]+'), '').trim();
    final extracted = _extractSection('تحديد هوية المنتج');
    if (extracted.isNotEmpty) return extracted.split('\n').first.replaceAll(RegExp(r'^[#*\-\s]+'), '').trim();
    return _t('المنتج الذي تم تحليله', 'Analyzed product');
  }

  String _amazonEgyptUrl() {
    final supplied = _valueText(_reportData?['amazon_eg_url']);
    final parsed = Uri.tryParse(supplied);
    if (parsed != null && (parsed.scheme == 'https' || parsed.scheme == 'http') && (parsed.host == 'amazon.eg' || parsed.host.endsWith('.amazon.eg'))) return supplied;
    final name = _productName();
    if (name.trim().isEmpty) return 'https://www.amazon.eg/';
    return 'https://www.amazon.eg/s?k=${Uri.encodeComponent(name)}';
  }

  List<Map<String, String>> _groundingSources(Map<String, dynamic> data) {
    final sources = <Map<String, String>>[];
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map) return sources;
    final candidate = Map<String, dynamic>.from(candidates.first as Map);
    final meta = candidate['groundingMetadata'];
    if (meta is! Map) return sources;
    final chunks = meta['groundingChunks'];
    if (chunks is! List) return sources;
    final seen = <String>{};
    for (final item in chunks) {
      if (item is! Map) continue;
      final web = item['web'];
      if (web is! Map) continue;
      final uri = web['uri']?.toString() ?? '';
      final title = web['title']?.toString().trim() ?? '';
      final parsed = Uri.tryParse(uri);
      if (parsed == null || (parsed.scheme != 'https' && parsed.scheme != 'http') || !seen.add(uri)) continue;
      sources.add(<String, String>{'title': title.isEmpty ? parsed.host : title, 'url': uri});
    }
    return sources;
  }

  Future<void> _analyze() async {
    if (_image == null) {
      _message(_t('صوّر المنتج أو اختر صورة أولًا', 'Capture or select a product image first'));
      return;
    }
    final activeKey = _apiProvider == 'openai' ? _openAiKey : _apiKey;
    if (activeKey.isEmpty) {
      _message(_t('أضف مفتاح API للمزود المختار من الإعدادات أولًا', 'Add an API key for the selected provider in Settings first'));
      await _settings();
      return;
    }
    if (_busy) return;
    // Set the guard before the first await so rapid taps cannot start duplicate requests.
    setState(() { _busy = true; _error = null; _result = ''; _reportData = null; _sources = <Map<String, String>>[]; });
    _startLoadingStages();
    final now = DateTime.now();
    late SharedPreferences prefs;
    var requestSent = false;
    var requestSucceeded = false;
    try {
      prefs = await SharedPreferences.getInstance();
      final bytes = await _image!.readAsBytes();
      final prompt = _makePrompt(_extraController.text.trim());
      final requestKey = '${_stableHash(base64Encode(bytes))}|$_apiProvider|$_model|$_market|$_condition|$_category|$_detailLevel|$_currency|$_webSearchEnabled|${_extraController.text.trim()}';
      if (prefs.getString('mango_cached_request_key') == requestKey) {
        final cached = prefs.getString('mango_cached_report') ?? '';
        if (cached.isNotEmpty) {
          _cacheHitCount++;
          await prefs.setInt('mango_api_cache_hit_count', _cacheHitCount);
          if (mounted) setState(() {
            _result = '$cached\n\n---\n${_t('ملاحظة: هذه نتيجة محفوظة محليًا من تحليل سابق وليست فحصًا جديدًا للسعر.', 'Note: this is a locally cached result from a previous analysis, not a fresh price check.')}';
            try { final rawData = prefs.getString('mango_cached_report_json'); _reportData = rawData == null ? null : Map<String, dynamic>.from(jsonDecode(rawData) as Map); } catch (_) { _reportData = null; }
            try { final rawSources = prefs.getString('mango_cached_sources_json'); _sources = rawSources == null ? <Map<String, String>>[] : (jsonDecode(rawSources) as List).whereType<Map>().map((e) => Map<String, String>.from(e.map((k,v) => MapEntry(k.toString(), v.toString())))).toList(); } catch (_) { _sources = <Map<String, String>>[]; }
            _selectedTab = 1;
          });
          _animateReportSections();
          _message(_t('استخدمت النتيجة المحفوظة لتوفير حصة API. لم يُرسل طلب جديد.', 'Used the cached result to save API quota. No new request was sent.'));
          return;
        }
      }
      if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
        final seconds = _cooldownUntil!.difference(now).inSeconds + 1;
        _message(_t('تم إيقاف الطلبات مؤقتًا بعد حد الاستخدام. جرّب بعد $seconds ثانية.', 'Requests are paused after a rate limit. Try again in $seconds seconds.'));
        return;
      }
      if (_lastRequestAt != null) {
        final remaining = const Duration(seconds: 15) - now.difference(_lastRequestAt!);
        if (remaining > Duration.zero) {
          _message(_t('لتوفير الحصة، استنى ${remaining.inSeconds + 1} ثانية قبل التحليل التالي.', 'To save quota, wait ${remaining.inSeconds + 1} seconds before the next scan.'));
          return;
        }
      }
      _lastRequestAt = now;
      await prefs.setInt('mango_last_api_request_ms', now.millisecondsSinceEpoch);
      _apiRequestCount++;
      await prefs.setInt('mango_api_request_count', _apiRequestCount);
      if (mounted) setState(() {});
      requestSent = true;
      final response = _apiProvider == 'openai' ? await _sendOpenAiRequest(prompt, bytes) : await _sendGeminiRequest(prompt, bytes);

      Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      } catch (_) {
        throw Exception('وصل رد غير مفهوم من الخدمة. حاول مرة أخرى بعد قليل.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorObject = data['error'];
        final apiMessage = errorObject is Map ? (errorObject['message']?.toString() ?? 'خطأ غير معروف') : (errorObject?.toString() ?? 'خطأ غير معروف');
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw Exception('مفتاح API غير صحيح أو غير مسموح له باستخدام هذا النموذج. راجع المفتاح واسم النموذج.');
        }
        if (response.statusCode == 429) {
          final retryAfter = int.tryParse(response.headers['retry-after'] ?? '') ?? 90;
          final cooldownSeconds = retryAfter < 90 ? 90 : (retryAfter > 3600 ? 3600 : retryAfter);
          _cooldownUntil = DateTime.now().add(Duration(seconds: cooldownSeconds));
          await prefs.setInt('mango_api_cooldown_until_ms', _cooldownUntil!.millisecondsSinceEpoch);
          final diagnostic = apiMessage;
          throw Exception('${_t('وصلت لحد استخدام مزود الذكاء الاصطناعي. أوقفنا المحاولات تلقائيًا لتجنب زيادة الضغط. التفاصيل:', 'The AI provider rate limit was reached. Automatic attempts are paused to avoid further requests. Details:')}\n$diagnostic\n\n${_t('لو السبب حصة يومية، قد تحتاج الانتظار حتى إعادة ضبطها؛ فترة الانتظار القصيرة لا تعيد الحصة اليومية.', 'If the daily quota is exhausted, you may need to wait for its reset; a short cooldown does not reset daily quota.')}');
        }
        if (response.statusCode == 404) throw Exception('لم يتم العثور على النموذج "$_model". تحقق من معرّف النموذج.');
        throw Exception('خطأ ${_apiProvider == 'openai' ? 'OpenAI' : 'Gemini'} (${response.statusCode}): $apiMessage');
      }

      String report;
      List<Map<String, String>> sources;
      if (_apiProvider == 'openai') {
        report = _openAiReport(data);
        sources = _openAiSources(data);
      } else {
        final candidates = data['candidates'];
        if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
          final feedback = data['promptFeedback'];
          if (feedback is Map && feedback['blockReason'] != null) throw Exception('لم تتم معالجة الطلب بسبب قيود السلامة: ${feedback['blockReason']}');
          throw Exception('لم يرجع النموذج تقريرًا. جرّب صورة أوضح أو نموذجًا آخر.');
        }
        final candidate = Map<String, dynamic>.from(candidates.first as Map);
        final content = candidate['content']; final parts = content is Map ? content['parts'] : null;
        report = parts is List ? parts.whereType<Map>().map((p) => p['text']?.toString() ?? '').where((v) => v.isNotEmpty).join('\n\n').trim() : '';
        sources = _groundingSources(data);
      }
      final decodedReport = _decodeReportObject(report);
      final isCurrentSchema = decodedReport != null && (decodedReport.containsKey('product_name') || decodedReport.containsKey('price_summary') || decodedReport.containsKey('offers') || decodedReport.containsKey('rarity_signals'));
      final Map<String, dynamic>? structuredReport = isCurrentSchema ? decodedReport : null;
      report = structuredReport != null ? _normalizeReport(report) : _normalizeLegacyReport(report);
      if (report.isEmpty) throw Exception('التقرير فارغ. قد يكون النموذج قد أنهى الطلب دون نص؛ جرّب مرة أخرى.');
      requestSucceeded = true;
      _apiSuccessCount++;
      await prefs.setInt('mango_api_success_count', _apiSuccessCount);

      final output = StringBuffer(report);
      if (sources.isNotEmpty) {
        output.write('\n\n## ${_t('مصادر البحث التي أعادها مزود الذكاء الاصطناعي', 'Web sources returned by the AI provider')}\n');
        for (final source in sources.take(10)) {
          output.write('\n- [${source['title']}](${source['url']})');
        }
      }
      final finalReport = output.toString();
      await prefs.setString('mango_cached_request_key', requestKey);
      await prefs.setString('mango_cached_report', finalReport);
      if (structuredReport != null) await prefs.setString('mango_cached_report_json', jsonEncode(structuredReport)); else await prefs.remove('mango_cached_report_json');
      await prefs.setString('mango_cached_sources_json', jsonEncode(sources));
      await prefs.remove('mango_api_cooldown_until_ms');
      _cooldownUntil = null;
      if (!mounted) return;
      setState(() { _result = finalReport; _reportData = structuredReport; _sources = sources; _selectedTab = 1; });
      _animateReportSections();
      await _saveHistory(finalReport, reportData: structuredReport, sources: sources);
      HapticFeedback.mediumImpact();
    } on SocketException {
      if (mounted) setState(() => _error = _friendlyError('SocketException')); 
    } on HttpException {
      if (mounted) setState(() => _error = _friendlyError('HttpException')); 
    } on FormatException {
      if (mounted) setState(() => _error = _friendlyError('FormatException')); 
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (requestSent && !requestSucceeded) {
        _apiFailureCount++;
        await prefs.setInt('mango_api_failure_count', _apiFailureCount);
      }
      _stopLoadingStages();
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _counterChip(String label, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: appThemeMode.value == ThemeMode.light ? const Color(0xFFF1F3FA) : const Color(0xFF1A263B), borderRadius: BorderRadius.circular(11)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: kAccent2),
        const SizedBox(width: 6),
        Text('$label: $count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  String _titleFromReport(String report) {
    for (final line in report.split('\n')) {
      final cleaned = line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s*'), '').replaceAll('*', '').trim();
      if (cleaned.isNotEmpty && !cleaned.startsWith('[') && !cleaned.startsWith('- ')) {
        return cleaned.length > 72 ? '${cleaned.substring(0, 69)}…' : cleaned;
      }
    }
    return 'تحليل منتج';
  }

  Future<void> _saveHistory(String report, {Map<String, dynamic>? reportData, List<Map<String, String>>? sources}) async {
    final entry = <String, dynamic>{
      'title': _valueText(reportData?['product_name']).isNotEmpty ? _valueText(reportData?['product_name']) : _titleFromReport(report),
      'report': report,
      'createdAt': DateTime.now().toIso8601String(),
      'market': _market,
      'model': _model,
      if (reportData != null) 'reportData': reportData,
      if (sources != null) 'sources': sources,
      'currency': _currency,
    };
    final next = <Map<String, dynamic>>[entry, ..._history].take(25).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('product_history_v2', jsonEncode(next));
    if (!mounted) return;
    setState(() => _history = next);
  }

  Future<void> _openHistory() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appThemeMode.value == ThemeMode.light ? Colors.white : kPanel,
        title: Row(children: [
          Expanded(child: Text(_t('سجل عمليات الفحص', 'Scan history'))),
          if (_history.isNotEmpty)
            IconButton(tooltip: _t('مسح السجل', 'Clear history'), onPressed: () async {
              final confirm = await showDialog<bool>(
                context: ctx,
                builder: (confirmCtx) => AlertDialog(
                  backgroundColor: appThemeMode.value == ThemeMode.light ? Colors.white : kPanel2,
                  title: Text(_t('مسح سجل الفحص؟', 'Clear scan history?')),
                  content: Text(_t('سيتم حذف التقارير المحفوظة محليًا من هذا الجهاز.', 'Saved reports will be deleted from this device.')),
                  actions: [TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(confirmCtx, true), child: const Text('مسح'))],
                ),
              );
              if (confirm == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('product_history_v2');
                if (mounted) setState(() => _history = <Map<String, dynamic>>[]);
                if (ctx.mounted) Navigator.pop(ctx);
                _message('تم مسح السجل');
              }
            }, icon: const Icon(Icons.delete_sweep_outlined)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: _history.isEmpty
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.history_rounded, size: 48, color: kMuted), SizedBox(height: 12), Text('لا توجد تقارير محفوظة حتى الآن'), SizedBox(height: 6), Text('بعد تحليل أول منتج سيظهر تقريرك هنا.', style: TextStyle(color: kMuted, fontSize: 12))]))
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 430),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF27334C)),
                    itemBuilder: (ctx, index) {
                      final item = _history[index];
                      final date = DateTime.tryParse(item['createdAt']?.toString() ?? '')?.toLocal();
                      final dateLabel = date == null ? '' : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(backgroundColor: Color(0xFFFFE1C4), child: Icon(Icons.document_scanner_outlined, color: Color(0xFFE75D00))),
                        title: Text(item['title']?.toString() ?? 'تحليل منتج', maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${item['market'] ?? 'السوق غير محدد'}${dateLabel.isEmpty ? '' : ' • $dateLabel'}', style: const TextStyle(color: kMuted, fontSize: 11)),
                        trailing: IconButton(tooltip: _favoriteTitles.contains(item['title']?.toString() ?? '') ? _t('إزالة من المفضلة', 'Remove favorite') : _t('حفظ في المفضلة', 'Save favorite'), onPressed: () => _toggleFavorite(item), icon: Icon(_favoriteTitles.contains(item['title']?.toString() ?? '') ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: kAccent)),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() { _result = item['report']?.toString() ?? ''; _reportData = item['reportData'] is Map ? Map<String, dynamic>.from(item['reportData'] as Map) : null; _sources = item['sources'] is List ? (item['sources'] as List).whereType<Map>().map((e) => Map<String, String>.from(e.map((k, v) => MapEntry(k.toString(), v.toString())))).toList() : <Map<String, String>>[]; _currency = item['currency']?.toString() ?? _currency; _selectedTab = 1; });
                        },
                      );
                    },
                  ),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('إغلاق', 'Close')))],
      ),
    );
  }

  Future<void> _copyCurrentReport() async {
    if (_result.trim().isEmpty) {
      _message(_t('حلّل منتجًا أولًا لتصدير التقرير.', 'Analyze a product first to export the report.'));
      return;
    }
    await Clipboard.setData(ClipboardData(text: _result));
    _message(_t('تم نسخ التقرير كاملًا. تقدر تلصقه في الملاحظات أو تحوّله إلى PDF من أي محرر مستندات.', 'Full report copied. Paste it into notes or export it as PDF from a document editor.'));
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    final title = item['title']?.toString() ?? _t('منتج محفوظ', 'Saved product');
    final next = List<String>.from(_favoriteTitles);
    if (next.contains(title)) {
      next.remove(title);
    } else {
      next.add(title);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('mango_favorite_titles', next);
    if (mounted) setState(() => _favoriteTitles = next);
    _message(next.contains(title) ? _t('اتضاف للمفضلة', 'Added to favorites') : _t('اتشال من المفضلة', 'Removed from favorites'));
  }

  Future<void> _compareSavedProducts() async {
    if (_history.length < 2) {
      _message(_t('حلّل منتجين على الأقل عشان تقدر تقارن بينهم.', 'Analyze at least two products to compare them.'));
      return;
    }
    int first = 0;
    int second = 1;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final a = _history[first];
        final b = _history[second];
        String field(Map<String, dynamic> item, String key) {
          final data = item['reportData'];
          if (data is Map && data[key] != null && data[key].toString().trim().isNotEmpty) return data[key].toString();
          return _t('غير متوفر في التقرير', 'Not available in report');
        }
        return AlertDialog(
          title: Text(_t('مقارنة المنتجات المحفوظة', 'Compare saved products')),
          content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(value: first, isExpanded: true, decoration: InputDecoration(labelText: _t('المنتج الأول', 'Product one')), items: List.generate(_history.length, (i) => DropdownMenuItem(value: i, child: Text(_history[i]['title']?.toString() ?? 'Product ${i+1}', overflow: TextOverflow.ellipsis))), onChanged: (v) { if (v != null) setDialogState(() { first = v; if (first == second) second = (first + 1) % _history.length; }); }),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(value: second, isExpanded: true, decoration: InputDecoration(labelText: _t('المنتج الثاني', 'Product two')), items: List.generate(_history.length, (i) => DropdownMenuItem(value: i, child: Text(_history[i]['title']?.toString() ?? 'Product ${i+1}', overflow: TextOverflow.ellipsis))), onChanged: (v) { if (v != null) setDialogState(() { second = v; if (first == second) first = (second + 1) % _history.length; }); }),
            const SizedBox(height: 16),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: ConstrainedBox(constraints: BoxConstraints(minWidth: MediaQuery.of(ctx).size.width - 80), child: Table(border: TableBorder.all(color: _borderColor), columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)}, children: [
              TableRow(children: [Padding(padding: const EdgeInsets.all(7), child: Text(_t('البند', 'Feature'), style: const TextStyle(fontWeight: FontWeight.bold))), Padding(padding: const EdgeInsets.all(7), child: Text(a['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold))), Padding(padding: const EdgeInsets.all(7), child: Text(b['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)))]),
              for (final row in <List<String>>[[ _t('ملخص السعر', 'Price summary'), 'price_summary'], [_t('الندرة', 'Rarity'), 'rarity_assessment'], [_t('المواصفات', 'Specs'), 'description_specifications']]) TableRow(children: [for (final value in <String>[row[0], field(a, row[1]), field(b, row[1])]) Padding(padding: const EdgeInsets.all(7), child: Text(value, style: const TextStyle(fontSize: 11)))]),
            ]))),
            const SizedBox(height: 8),
            Text(_t('المقارنة مبنية على التقارير المحفوظة وقد تكون تواريخها مختلفة؛ راجع مصادر الأسعار قبل اتخاذ قرار.', 'This comparison uses saved reports that may have different dates; verify price sources before deciding.'), style: TextStyle(color: _mutedColor, fontSize: 11)),
          ]))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('إغلاق', 'Close')))],
        );
      }),
    );
  }

  Widget _quickActions() {
    final actions = <({IconData icon, String title, String subtitle, VoidCallback tap})>[
      (icon: Icons.history_rounded, title: _t('سجل التحليلات', 'History'), subtitle: '${_history.length} ${_t('تقرير', 'reports')}', tap: _openHistory),
      (icon: Icons.compare_arrows_rounded, title: _t('قارن منتجين', 'Compare products'), subtitle: _t('من التقارير المحفوظة', 'Saved reports'), tap: _compareSavedProducts),
      (icon: Icons.price_change_rounded, title: _t('الأسعار', 'Prices'), subtitle: _t('العروض والمصادر', 'Offers & sources'), tap: () => setState(() => _selectedTab = 2)),
      (icon: Icons.diamond_outlined, title: _t('الندرة', 'Rarity'), subtitle: _t('الأدلة والثقة', 'Evidence & confidence'), tap: () => setState(() => _selectedTab = 3)),
      (icon: Icons.ios_share_rounded, title: _t('تصدير التقرير', 'Export report'), subtitle: _t('نسخ النص كاملًا', 'Copy full text'), tap: _copyCurrentReport),
      (icon: Icons.calculate_outlined, title: _t('حاسبة الأرباح', 'Profit calculator'), subtitle: _t('حساب محلي بلا AI', 'Offline calculation'), tap: () => _message(_t('حاسبة الأرباح موجودة أسفل الصفحة الرئيسية.', 'The profit calculator is lower on the home page.'))),
    ];
    return _surfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _subsectionHeader(Icons.dashboard_customize_rounded, _t('أدوات سريعة', 'Quick tools')),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: actions.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.of(context).size.width < 360 ? 1 : 2, mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: MediaQuery.of(context).size.width < 360 ? 4.0 : 2.45), itemBuilder: (context, i) { final a = actions[i]; return InkWell(onTap: a.tap, borderRadius: BorderRadius.circular(15), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(15), border: Border.all(color: _borderColor)), child: Row(children: [Icon(a.icon, color: kAccent, size: 21), const SizedBox(width: 8), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(a.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mutedColor, fontSize: 9))]))]))); }),
    ]));
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      try {
        final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!opened) _message('تعذر فتح الرابط على هذا الجهاز');
      } catch (_) {
        _message('تعذر فتح الرابط');
      }
    } else {
      _message('الرابط غير صالح');
    }
  }

  Future<void> _saveChoice(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  double _number(TextEditingController controller) => double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  Widget _profitCalculator() {
    final cost = _number(_costController);
    final sell = _number(_sellController);
    final fees = _number(_feesController);
    final shipping = _number(_shippingController);
    final profit = sell - cost - fees - shipping;
    final margin = sell > 0 ? (profit / sell) * 100 : 0.0;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: appThemeMode.value == ThemeMode.light ? Colors.white : kPanel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: appThemeMode.value == ThemeMode.light ? const Color(0xFFE0E5EF) : const Color(0xFF2A3852)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(_t('حاسبة ربح التاجر', 'Seller profit calculator'), _t('احسب هامش الربح بدون أي طلبات ذكاء اصطناعي أو استهلاك للحصة.', 'Calculate profit without any AI requests or quota usage.'), Icons.calculate_outlined),
        Row(children: [
          Expanded(child: TextField(controller: _costController, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: _t('سعر الشراء', 'Cost price'), prefixIcon: const Icon(Icons.shopping_bag_outlined)))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _sellController, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: _t('سعر البيع', 'Sale price'), prefixIcon: const Icon(Icons.sell_outlined)))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _feesController, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: _t('عمولات ومصاريف', 'Fees & expenses'), prefixIcon: const Icon(Icons.receipt_long_outlined)))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _shippingController, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: _t('الشحن', 'Shipping'), prefixIcon: const Icon(Icons.local_shipping_outlined)))),
        ]),
        const SizedBox(height: 13),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: profit >= 0 ? const Color(0x1E32B987) : const Color(0x20F06475), borderRadius: BorderRadius.circular(15)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_t('صافي الربح المتوقع', 'Estimated net profit'), style: const TextStyle(color: kMuted, fontSize: 12)), const SizedBox(height: 4), Text(profit.toStringAsFixed(2), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: profit >= 0 ? const Color(0xFF31C48D) : const Color(0xFFFF7A8A)))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(_t('هامش الربح', 'Profit margin'), style: const TextStyle(fontSize: 10, color: kMuted)), const SizedBox(height: 3), Text('${margin.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))])),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: kAccent)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 12, height: 1.45)),
        ])),
      ]),
    );
  }

  String _translateOption(String item) {
    const translations = <String, String>{
      'مصر': 'Egypt', 'السعودية': 'Saudi Arabia', 'الإمارات': 'United Arab Emirates', 'الكويت': 'Kuwait', 'قطر': 'Qatar', 'الأردن': 'Jordan', 'الولايات المتحدة': 'United States', 'المملكة المتحدة': 'United Kingdom', 'السوق العالمي': 'Global market',
      'تلقائي': 'Automatic', 'إلكترونيات': 'Electronics', 'أجهزة منزلية': 'Home appliances', 'ملابس وأحذية': 'Clothing & shoes', 'عطور ومستحضرات': 'Perfumes & cosmetics', 'ألعاب ومقتنيات': 'Toys & collectibles', 'تحف وأنتيكات': 'Antiques', 'كتب ومطبوعات': 'Books & prints', 'أدوات ومعدات': 'Tools & equipment', 'أخرى': 'Other',
      'غير محددة': 'Unspecified', 'جديد': 'New', 'مستعمل': 'Used', 'مجدد / Refurbished': 'Refurbished', 'قطعة لهواة الاقتناء': 'Collectible', 'سريع': 'Fast', 'تفصيلي': 'Detailed',
    };
    return appEnglish.value ? (translations[item] ?? item) : item;
  }

  Widget _dropdown({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged, IconData? icon}) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon, size: 19)),
      items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(_translateOption(item), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _featurePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(50), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: kAccent2), const SizedBox(width: 6), Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFFD8E0F4)))],),
    );
  }

  Color get _surfaceColor => appThemeMode.value == ThemeMode.light ? Colors.white : kPanel;
  Color get _borderColor => appThemeMode.value == ThemeMode.light ? const Color(0xFFE8E1D9) : const Color(0xFF34373C);
  Color get _mutedColor => appThemeMode.value == ThemeMode.light ? const Color(0xFF727781) : kMuted;
  Color get _bodyColor => appThemeMode.value == ThemeMode.light ? const Color(0xFF282A2E) : const Color(0xFFE8E9EC);

  Widget _surfaceCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16), Color? color}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? _surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
        boxShadow: appThemeMode.value == ThemeMode.light
            ? const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 5))]
            : const [],
      ),
      child: child,
    );
  }

  Widget _pageHeading(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: kAccent, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: _mutedColor, fontSize: 12, height: 1.5)),
        ])),
      ]),
    );
  }

  Widget _markdown(String text) {
    if (text.trim().isEmpty) return Text(_t('لا توجد معلومات في هذا القسم حتى الآن.', 'No information is available in this section yet.'), style: TextStyle(color: _mutedColor, height: 1.6));
    return MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: (text, href, title) { if (href != null) _openUrl(href); },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 14, height: 1.78, color: _bodyColor),
        h1: const TextStyle(fontSize: 21, height: 1.35, fontWeight: FontWeight.w900, color: kAccent),
        h2: const TextStyle(fontSize: 18, height: 1.4, fontWeight: FontWeight.w800, color: kAccent),
        h3: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _bodyColor),
        a: const TextStyle(color: kAccent, decoration: TextDecoration.underline),
        listBullet: const TextStyle(color: kAccent),
        blockquote: TextStyle(color: _mutedColor, fontStyle: FontStyle.italic),
        tableHead: TextStyle(fontWeight: FontWeight.w800, color: _bodyColor),
        tableBody: TextStyle(fontSize: 12, height: 1.5, color: _bodyColor),
        tableBorder: TableBorder.all(color: _borderColor, borderRadius: BorderRadius.circular(8)),
        tableCellsPadding: const EdgeInsets.all(8),
        code: TextStyle(color: _bodyColor, backgroundColor: kAccent.withValues(alpha: 0.08)),
      ),
    );
  }

  Widget _reportOrEmpty({required String text, required IconData icon, required String title, required String hint}) {
    if (_result.isNotEmpty && text.trim().isNotEmpty) return _markdown(text);
    if (_reportData != null && text.trim().isNotEmpty) return _markdown(text);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 62, height: 62, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Icon(icon, size: 30, color: kAccent)),
      const SizedBox(height: 14),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text(hint, textAlign: TextAlign.center, style: TextStyle(color: _mutedColor, height: 1.6, fontSize: 12)),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: () => setState(() => _selectedTab = 0), icon: const Icon(Icons.add_a_photo_outlined), label: Text(_t('ابدأ بتحليل منتج', 'Analyze a product'))),
    ]);
  }

  List<Map<String, dynamic>> _offers() {
    final value = _reportData?['offers'];
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> _raritySignals() {
    final value = _reportData?['rarity_signals'];
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  bool get _hasVerifiedAmazonEgLink {
    final url = _valueText(_reportData?['amazon_eg_url']);
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && (uri.host == 'amazon.eg' || uri.host.endsWith('.amazon.eg'));
  }

  Widget _buildHomePage() {
    final isConnected = _apiProvider == 'openai' ? _openAiKey.isNotEmpty : _apiKey.isNotEmpty;
    return ListView(
      key: const PageStorageKey<String>('mango_home_page'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFFFF8A1C), Color(0xFFE75D00), Color(0xFF302018)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x30F56D00), blurRadius: 24, offset: Offset(0, 11))],
          ),
          child: Stack(children: [
            Positioned(left: -25, bottom: -34, child: Container(width: 126, height: 126, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 20)))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 39, height: 39, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.17), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 24)),
                const SizedBox(width: 10),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MANGO LENS', style: TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 1.2, fontWeight: FontWeight.w900)), Text('PRODUCT INTELLIGENCE', style: TextStyle(color: Color(0xFFFFE2C8), fontSize: 9, letterSpacing: 1.0, fontWeight: FontWeight.w700))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(30)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bolt_rounded, color: Colors.white, size: 15), SizedBox(width: 4), Text('1 API CALL', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))])),
              ]),
              const SizedBox(height: 22),
              Text(_t('اعرف قيمة أي منتج\nمن صورة واحدة.', 'Know a product\nfrom one photo.'), style: const TextStyle(color: Colors.white, fontSize: 29, height: 1.18, fontWeight: FontWeight.w900, letterSpacing: -0.65)),
              const SizedBox(height: 10),
              Text(_t('معلومات منظمة، مقارنة أسعار، وروابط شراء — في تقرير موحد بطلب تحليل واحد.', 'Organized product details, price comparison, and shopping links — in one unified analysis request.'), style: const TextStyle(color: Color(0xFFFFF2E7), fontSize: 12, height: 1.65)),
              const SizedBox(height: 17),
              Wrap(spacing: 7, runSpacing: 7, children: [
                _heroBadge(Icons.price_change_rounded, _t('مقارنة أسعار', 'Price compare')),
                _heroBadge(Icons.table_chart_rounded, _t('جداول مرتبة', 'Smart tables')),
                _heroBadge(Icons.savings_outlined, _t('توفير الطلبات', 'Quota saver')),
              ]),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        _quickActions(),
        const SizedBox(height: 23),
        _pageHeading(_t('حلّل منتجًا جديدًا', 'Analyze a new product'), _t('ارفع صورة واضحة للمنتج أو لملصق الموديل.', 'Upload a clear photo of the product or model label.'), Icons.add_a_photo_outlined),
        InkWell(
          onTap: _busy ? null : _imageOptions,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _image == null ? 190 : 260,
            decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: _image == null ? _borderColor : kAccent, width: _image == null ? 1 : 1.6)),
            child: _image == null
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 62, height: 62, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.add_photo_alternate_outlined, size: 31, color: kAccent)),
                    const SizedBox(height: 12),
                    Text(_t('اضغط لاختيار صورة المنتج', 'Tap to choose a product image'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 5),
                    Text(_t('الكاميرا أو المعرض • JPG / PNG / WebP', 'Camera or gallery • JPG / PNG / WebP'), style: TextStyle(color: _mutedColor, fontSize: 11)),
                  ])
                : ClipRRect(borderRadius: BorderRadius.circular(23), child: Stack(fit: StackFit.expand, children: [
                    GestureDetector(onTap: () => showDialog<void>(context: context, builder: (_) => Dialog(backgroundColor: Colors.black, insetPadding: const EdgeInsets.all(12), child: InteractiveViewer(child: Image.file(_image!, fit: BoxFit.contain)))), child: Image.file(_image!, fit: BoxFit.contain)),
                    Positioned(top: 8, left: 8, child: IconButton.filled(onPressed: () => setState(() { _image = null; _result = ''; _reportData = null; _sources = <Map<String, String>>[]; }), style: IconButton.styleFrom(backgroundColor: const Color(0xDD202124), foregroundColor: Colors.white), icon: const Icon(Icons.close_rounded), tooltip: _t('إزالة الصورة', 'Remove image'))),
                    Positioned(right: 10, bottom: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xDD202124), borderRadius: BorderRadius.circular(30)), child: Text(_t('اضغط للتكبير', 'Tap to zoom'), style: const TextStyle(color: Colors.white, fontSize: 11)))),
                  ])),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _chooseImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: Text(_t('الكاميرا', 'Camera')), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(47), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _chooseImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: Text(_t('المعرض', 'Gallery')), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(47), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
        ]),
        const SizedBox(height: 22),
        _pageHeading(_t('إعدادات التقرير', 'Report setup'), _t('اختياراتك تُرسل ضمن نفس طلب التحليل ولا تنشئ طلبات منفصلة.', 'Your choices are included in the same analysis request.'), Icons.tune_rounded),
        _surfaceCard(child: Column(children: [
          LayoutBuilder(builder: (context, constraints) => Wrap(spacing: 10, runSpacing: 12, children: [
            SizedBox(width: (constraints.maxWidth - 10) / 2, child: _dropdown(label: _t('السوق', 'Market'), value: _market, items: const ['مصر', 'السعودية', 'الإمارات', 'الكويت', 'قطر', 'الأردن', 'الولايات المتحدة', 'المملكة المتحدة', 'السوق العالمي'], icon: Icons.public_rounded, onChanged: (v) { if (v == null) return; setState(() => _market = v); _saveChoice('product_market', v); })),
            SizedBox(width: (constraints.maxWidth - 10) / 2, child: DropdownButtonFormField<String>(
              value: _currency,
              isExpanded: true,
              decoration: InputDecoration(labelText: _t('عملة الأسعار', 'Price currency'), prefixIcon: const Icon(Icons.currency_exchange_rounded, size: 19)),
              items: [DropdownMenuItem(value: 'EGP', child: Text(_t('جنيه EGP', 'Pound EGP'))), DropdownMenuItem(value: 'USD', child: Text(_t('دولار USD', 'Dollar USD'))), DropdownMenuItem(value: 'SAR', child: Text(_t('ريال SAR', 'Riyal SAR'))), DropdownMenuItem(value: 'EUR', child: Text(_t('يورو EUR', 'Euro EUR')))],
              onChanged: (v) { if (v == null) return; setState(() => _currency = v); _saveChoice('product_currency', v); },
            )),
          ])),
          const SizedBox(height: 12),
          _dropdown(label: _t('تصنيف المنتج', 'Product category'), value: _category, items: const ['تلقائي', 'إلكترونيات', 'أجهزة منزلية', 'ملابس وأحذية', 'عطور ومستحضرات', 'ألعاب ومقتنيات', 'تحف وأنتيكات', 'كتب ومطبوعات', 'أدوات ومعدات', 'أخرى'], icon: Icons.category_outlined, onChanged: (v) { if (v == null) return; setState(() => _category = v); _saveChoice('product_category', v); }),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) => Wrap(spacing: 10, runSpacing: 12, children: [
            SizedBox(width: (constraints.maxWidth - 10) / 2, child: _dropdown(label: _t('حالة المنتج', 'Condition'), value: _condition, items: const ['غير محددة', 'جديد', 'مستعمل', 'مجدد / Refurbished', 'قطعة لهواة الاقتناء'], icon: Icons.inventory_2_outlined, onChanged: (v) { if (v == null) return; setState(() => _condition = v); _saveChoice('product_condition', v); })),
            SizedBox(width: (constraints.maxWidth - 10) / 2, child: _dropdown(label: _t('التفاصيل', 'Detail level'), value: _detailLevel, items: const ['سريع', 'تفصيلي'], icon: Icons.subject_rounded, onChanged: (v) { if (v == null) return; setState(() => _detailLevel = v); _saveChoice('product_detail', v); })),
          ])),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: Container(width: 39, height: 39, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.travel_explore_rounded, color: kAccent)),
            title: Text(_t('البحث عن أسعار حديثة', 'Search current prices'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            subtitle: Text(_webSearchEnabled ? _t('مفعّل داخل طلب التحليل نفسه، من غير طلب بحث منفصل.', 'Included in the same analysis request; no separate search request.') : _t('مغلق؛ الأسعار ستكون تقديرية وغير متحققة لحظيًا.', 'Off; prices will be estimates, not live-verified.'), style: TextStyle(color: _mutedColor, fontSize: 11, height: 1.4)),
            value: _webSearchEnabled,
            activeColor: kAccent,
            onChanged: (value) async { setState(() => _webSearchEnabled = value); final prefs = await SharedPreferences.getInstance(); await prefs.setBool('mango_web_search_enabled', value); },
          ),
          TextField(controller: _extraController, maxLines: 2, minLines: 1, textInputAction: TextInputAction.newline, decoration: InputDecoration(labelText: _t('تفاصيل إضافية (اختياري)', 'Extra details (optional)'), hintText: _t('مثال: ابحث عن إصدار 2022 أو عن سعر المنتج المستعمل...', 'Example: look for the 2022 edition or used prices...'), prefixIcon: const Icon(Icons.edit_note_rounded), alignLabelWithHint: true)),
        ])),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _analyze,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), backgroundColor: kAccent, foregroundColor: Colors.white, disabledBackgroundColor: appThemeMode.value == ThemeMode.light ? const Color(0xFFFFD6B0) : const Color(0xFF754323), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)), elevation: 0),
          icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded, size: 22),
          label: Text(_busy ? _t('جارٍ تحليل المنتج في طلب واحد...', 'Analyzing in one request...') : _t('حلّل المنتج الآن', 'Analyze product now'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ),
        if (_busy) ...[
          const SizedBox(height: 12),
          const ClipRRect(borderRadius: BorderRadius.all(Radius.circular(4)), child: LinearProgressIndicator(minHeight: 4, color: kAccent, backgroundColor: Color(0x33FF7900))),
          const SizedBox(height: 8),
          Text(_loadingStage.isEmpty ? _t('جاري تحليل الصورة...', 'Analyzing image...') : _loadingStage, textAlign: TextAlign.center, style: TextStyle(color: _mutedColor, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_t('الصورة والبحث والأسعار والمواصفات تُجمع داخل استدعاء التحليل نفسه.', 'Image, web search, prices, and specs are handled in the same analysis call.'), textAlign: TextAlign.center, style: TextStyle(color: _mutedColor, fontSize: 10)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 13),
          _surfaceCard(color: appThemeMode.value == ThemeMode.light ? const Color(0xFFFFF0EA) : const Color(0xFF38251F), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.error_outline_rounded, color: Color(0xFFE45D32)), const SizedBox(width: 10), Expanded(child: Text(_error!, style: const TextStyle(height: 1.55))), IconButton(onPressed: () => setState(() => _error = null), icon: const Icon(Icons.close_rounded, size: 19))]), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: [FilledButton.icon(onPressed: _busy ? null : _analyze, icon: const Icon(Icons.refresh_rounded), label: Text(_t('إعادة المحاولة', 'Retry')), style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white)), OutlinedButton.icon(onPressed: _settings, icon: const Icon(Icons.settings_outlined), label: Text(_t('الإعدادات', 'Settings')))])])),
        ],
        const SizedBox(height: 17),
        _surfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13)), child: Icon(isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: kAccent)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isConnected ? _t('مزود الذكاء الاصطناعي جاهز', 'AI provider ready') : _t('اربط مفتاح API للبدء', 'Add an API key to start'), style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(isConnected ? '${_apiProvider == 'openai' ? 'OpenAI' : 'Gemini'} • $_model' : _t('يُحفظ المفتاح على هذا الجهاز فقط', 'The key is saved only on this device'), style: TextStyle(color: _mutedColor, fontSize: 11))])), if (!isConnected) TextButton(onPressed: _settings, child: Text(_t('إعداد', 'Setup')))]),
          const SizedBox(height: 17),
          Row(children: [Icon(Icons.speed_rounded, color: kAccent, size: 20), const SizedBox(width: 8), Expanded(child: Text(_t('استهلاك API على هذا الجهاز', 'API usage on this device'), style: const TextStyle(fontWeight: FontWeight.w900))), Text(_t('محلي', 'LOCAL'), style: TextStyle(color: _mutedColor, fontSize: 9, letterSpacing: 0.8))]),
          const SizedBox(height: 11),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _counterChip(_t('مرسلة', 'Sent'), _apiRequestCount, Icons.outbound_rounded),
            _counterChip(_t('ناجحة', 'Success'), _apiSuccessCount, Icons.check_circle_outline_rounded),
            _counterChip(_t('فاشلة', 'Failed'), _apiFailureCount, Icons.error_outline_rounded),
            _counterChip(_t('من الكاش', 'Cached'), _cacheHitCount, Icons.cached_rounded),
          ]),
          const SizedBox(height: 9),
          Text(_t('العداد يحصي استدعاءات التحليل التي يرسلها التطبيق، ولا يحسب أي بحث داخلي قد تجريه خدمة Gemini ضمن الطلب نفسه.', 'Counts analysis calls sent by the app, not internal searches that Gemini may perform within a call.'), style: TextStyle(color: _mutedColor, fontSize: 10, height: 1.55)),
        ])),
        const SizedBox(height: 16),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.only(top: 8),
          leading: Container(width: 39, height: 39, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.calculate_outlined, color: kAccent)),
          title: Text(_t('حاسبة ربح التاجر', 'Seller profit calculator'), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(_t('تعمل بدون أي طلبات API', 'Works without API calls'), style: TextStyle(color: _mutedColor, fontSize: 11)),
          children: [_profitCalculator()],
        ),
        const SizedBox(height: 14),
        _surfaceCard(padding: const EdgeInsets.all(13), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lock_outline_rounded, color: kAccent, size: 20), const SizedBox(width: 9),
          Expanded(child: Text(_t('الصورة تُرسل إلى مزود الذكاء الاصطناعي المختار وقت التحليل، وسجل التقارير محفوظ محليًا. مفاتيح API على الجهاز مناسبة للاختبار الشخصي فقط، وليس لإصدار تجاري عام.', 'The photo is sent to the selected AI provider during analysis, and report history is stored locally. Device-stored API keys are suitable for personal testing only, not a public commercial release.'), style: TextStyle(color: _mutedColor, fontSize: 10, height: 1.6))),
        ])),
        const SizedBox(height: 18),
        Center(child: Column(children: [Text(_t('MANGO LENS • صناعة شركة مانجو • المؤسس مصطفى ماجد', 'MANGO LENS • MANGO Company • Founder Mostafa Maged'), textAlign: TextAlign.center, style: TextStyle(color: _mutedColor, fontSize: 10, letterSpacing: 0.2)), const SizedBox(height: 4), Wrap(alignment: WrapAlignment.center, children: [TextButton(onPressed: _showPrivacy, child: Text(_t('الخصوصية', 'Privacy'), style: const TextStyle(fontSize: 11))), TextButton(onPressed: _showAbout, child: Text(_t('عن التطبيق • v1.9.0', 'About • v1.9.0'), style: const TextStyle(fontSize: 11)))])])),
      ],
    );
  }

  Widget _heroBadge(IconData icon, String label) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white.withValues(alpha: 0.13))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: Colors.white), const SizedBox(width: 5), Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))]));
  }

  Widget _buildProductPage() {
    final identity = _valueText(_reportData?['product_identity']).isNotEmpty ? _valueText(_reportData?['product_identity']) : _extractSection('تحديد هوية المنتج');
    final specs = _valueText(_reportData?['description_specifications']).isNotEmpty ? _valueText(_reportData?['description_specifications']) : _extractSection('الوصف والمواصفات');
    final authenticity = _valueText(_reportData?['authenticity_condition']).isNotEmpty ? _valueText(_reportData?['authenticity_condition']) : _extractSection('الأصالة والحالة');
    final tips = _valueText(_reportData?['buying_tips']).isNotEmpty ? _valueText(_reportData?['buying_tips']) : _extractSection('نصائح قبل الشراء');
    final quickSummary = _valueText(_reportData?['quick_summary']).isNotEmpty ? _valueText(_reportData?['quick_summary']) : _extractSection('الخلاصة السريعة');
    final name = _productName();
    return ListView(key: const PageStorageKey<String>('mango_product_page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
      _pageHeading(_t('معلومات المنتج', 'Product details'), _t('الهوية والمواصفات والحالة في صفحة واحدة مرتبة.', 'Identity, specifications, and condition in one organized page.'), Icons.inventory_2_outlined),
      if (_result.isEmpty) _surfaceCard(child: _reportOrEmpty(text: '', icon: Icons.document_scanner_outlined, title: _t('لم يتم تحليل منتج بعد', 'No product analyzed yet'), hint: _t('اختر صورة من الصفحة الرئيسية وسيظهر التقرير هنا.', 'Choose a photo on Home and your report will appear here.')))
      else ...[
        _surfaceCard(color: appThemeMode.value == ThemeMode.light ? const Color(0xFFFFF5EC) : const Color(0xFF30231B), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.auto_awesome_mosaic_rounded, color: kAccent, size: 28)),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, height: 1.3)), const SizedBox(height: 6), Text('${_valueText(_reportData?['brand']).isEmpty ? '' : _valueText(_reportData?['brand'])}${_valueText(_reportData?['brand']).isNotEmpty && _valueText(_reportData?['model']).isNotEmpty ? ' • ' : ''}${_valueText(_reportData?['model'])}', style: TextStyle(color: _mutedColor, fontSize: 12)), const SizedBox(height: 7), Wrap(spacing: 6, runSpacing: 5, children: [_miniTag(_currencyLabel(), Icons.currency_exchange_rounded), _miniTag(_market, Icons.public_rounded)])]))
        ])),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _copyCurrentReport, icon: const Icon(Icons.ios_share_rounded), label: Text(_t('نسخ / تصدير التقرير', 'Copy / export report'))),
        const SizedBox(height: 13),
        AnimatedOpacity(opacity: _reportRevealStep >= 1 ? 1 : 0, duration: const Duration(milliseconds: 240), child: _surfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_subsectionHeader(Icons.summarize_outlined, _t('الخلاصة السريعة', 'Quick summary')), _markdown(quickSummary)]))),
        const SizedBox(height: 13),
        AnimatedOpacity(opacity: _reportRevealStep >= 2 ? 1 : 0, duration: const Duration(milliseconds: 240), child: _surfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_subsectionHeader(Icons.fingerprint_rounded, _t('التعرّف على المنتج', 'Product identification')), _markdown(identity)]))),
        const SizedBox(height: 13),
        AnimatedOpacity(opacity: _reportRevealStep >= 3 ? 1 : 0, duration: const Duration(milliseconds: 240), child: _surfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_subsectionHeader(Icons.settings_suggest_outlined, _t('الوصف والمواصفات', 'Description & specs')), _markdown(specs)]))),
        const SizedBox(height: 13),
        AnimatedOpacity(opacity: _reportRevealStep >= 4 ? 1 : 0, duration: const Duration(milliseconds: 240), child: _surfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_subsectionHeader(Icons.verified_user_outlined, _t('الحالة ومؤشرات الأصالة', 'Condition & authenticity')), _markdown(authenticity)]))),
        const SizedBox(height: 13),
        AnimatedOpacity(opacity: _reportRevealStep >= 5 ? 1 : 0, duration: const Duration(milliseconds: 240), child: _surfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_subsectionHeader(Icons.lightbulb_outline_rounded, _t('نصائح قبل الشراء', 'Buying tips')), _markdown(tips)]))),
        const SizedBox(height: 13),
        FilledButton.icon(onPressed: () => setState(() => _selectedTab = 2), icon: const Icon(Icons.price_check_rounded), label: Text(_t('عرض الأسعار وروابط الشراء', 'View prices & shopping links')), style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
      ],
    ]);
  }

  Widget _buildPricesPage() {
    final summary = _valueText(_reportData?['price_summary']).isNotEmpty ? _valueText(_reportData?['price_summary']) : (_extractSection('ملخص الأسعار').isNotEmpty ? _extractSection('ملخص الأسعار') : (_extractSection('الأسعار والعروض').isNotEmpty ? _extractSection('الأسعار والعروض') : _extractSection('عروض الأسعار')));
    final purchaseComparison = _valueText(_reportData?['purchase_links_comparison']).isNotEmpty ? _valueText(_reportData?['purchase_links_comparison']) : _extractSection('روابط الشراء والمقارنة');
    final offers = _offers();
    return ListView(key: const PageStorageKey<String>('mango_prices_page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
      _pageHeading(_t('الأسعار والشراء', 'Prices & shopping'), _t('عروض موثقة وروابط قابلة للفتح، بعملة التقرير التي اخترتها.', 'Offers and links in your chosen report currency.'), Icons.price_check_rounded),
      if (_result.isEmpty) _surfaceCard(child: _reportOrEmpty(text: '', icon: Icons.price_change_outlined, title: _t('الأسعار هتظهر هنا', 'Prices will appear here'), hint: _t('حلّل صورة المنتج مع تفعيل البحث على الإنترنت للحصول على أسعار وروابط أحدث.', 'Analyze a product with web search enabled to look for current prices and links.')))
      else ...[
        _surfaceCard(color: appThemeMode.value == ThemeMode.light ? const Color(0xFFFFF5EC) : const Color(0xFF30231B), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 43, height: 43, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.currency_exchange_rounded, color: kAccent, size: 23)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_t('عملة عرض الأسعار', 'Price display currency'), style: TextStyle(color: _mutedColor, fontSize: 11)), const SizedBox(height: 3), Text(_currencyLabel(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))]))]), const SizedBox(height: 13), _markdown(summary)])),
        if (_valueText(_reportData?['price_history_note']).isNotEmpty) ...[
          const SizedBox(height: 10),
          _surfaceCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.show_chart_rounded, color: kAccent), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_subsectionHeader(Icons.history_toggle_off_rounded, _t('بيانات تغيّر السعر', 'Price history data')), _markdown(_valueText(_reportData?['price_history_note']))]))])),
        ],
        const SizedBox(height: 14),
        _surfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _subsectionHeader(Icons.table_chart_rounded, _t('جدول عروض الأسعار', 'Offer comparison table')),
          if (offers.isNotEmpty)
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              columnSpacing: 18,
              horizontalMargin: 8,
              columns: [DataColumn(label: Text(_t('المتجر', 'Store'))), DataColumn(label: Text(_t('السعر الأصلي', 'Listed price'))), DataColumn(label: Text(_t('بالعملة المختارة', 'Converted price'))), DataColumn(label: Text(_t('الحالة', 'Condition'))), DataColumn(label: Text(_t('الرابط', 'Link')))],
              rows: offers.map((offer) {
                final url = _valueText(offer['url']);
                final currency = _valueText(offer['currency']);
                final original = _formatMoney(_valueText(offer['price']), currency);
                final converted = _valueText(offer['converted_price']);
                final state = [_valueText(offer['condition']), _valueText(offer['availability']), _valueText(offer['shipping']).isNotEmpty ? '${_t('الشحن', 'Shipping')}: ${_valueText(offer['shipping'])}' : '', _valueText(offer['checked_at']).isNotEmpty ? '${_t('التحقق', 'Checked')}: ${_valueText(offer['checked_at'])}' : ''].where((s) => s.isNotEmpty).join('\n');
                final validUrl = Uri.tryParse(url);
                return DataRow(cells: [
                  DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 145), child: Text(_valueText(offer['store']).isEmpty ? '—' : _valueText(offer['store']), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)))),
                  DataCell(Text(original.isEmpty ? '—' : original)),
                  DataCell(Text(converted.isEmpty ? '—' : _formatMoney(converted, _currency), style: TextStyle(color: converted.isNotEmpty ? kAccent : _mutedColor, fontWeight: FontWeight.w800))),
                  DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 130), child: Text(state.isEmpty ? '—' : state, maxLines: 3, overflow: TextOverflow.ellipsis))),
                  DataCell(IconButton(tooltip: _t('فتح العرض', 'Open offer'), onPressed: validUrl != null && (validUrl.scheme == 'https' || validUrl.scheme == 'http') ? () => _openUrl(url) : null, icon: const Icon(Icons.open_in_new_rounded, color: kAccent, size: 20))),
                ]);
              }).toList(),
            ))
          else _markdown(_extractSection('عروض الأسعار').isNotEmpty ? _extractSection('عروض الأسعار') : purchaseComparison.isNotEmpty ? purchaseComparison : summary),
          if (offers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_t('ملاحظة: السعر بعملة التقرير لا يظهر إلا عندما أعاد النموذج تحويلًا موثقًا؛ علامة (—) تعني أنه لم يتم اختراع سعر صرف.', 'Converted prices are shown only when backed by a sourced exchange rate; (—) means no rate was invented.'), style: TextStyle(color: _mutedColor, fontSize: 10, height: 1.55)),
          ],
        ])),
        const SizedBox(height: 13),
        _surfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _subsectionHeader(Icons.shopping_bag_outlined, _t('أمازون مصر', 'Amazon Egypt')),
          Text(_hasVerifiedAmazonEgLink ? _t('تم إرجاع رابط صفحة من Amazon.eg ضمن نتائج التحليل. تحقق من الموديل والسعر قبل الشراء.', 'A product page URL from Amazon.eg was returned. Verify the model and price before purchase.') : _t('لو لم يظهر رابط منتج مباشر موثوق، افتح البحث داخل أمازون مصر. رابط البحث لا يعني أن المنتج متوفر بالتأكيد.', 'When no verified product page was found, search Amazon Egypt. A search link does not guarantee availability.'), style: TextStyle(color: _mutedColor, fontSize: 12, height: 1.6)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _openUrl(_amazonEgyptUrl()), icon: const Icon(Icons.open_in_new_rounded), label: Text(_hasVerifiedAmazonEgLink ? _t('فتح صفحة المنتج على Amazon.eg', 'Open Amazon.eg product page') : _t('ابحث عن المنتج في Amazon.eg', 'Search for product on Amazon.eg')), style: FilledButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
        ])),
        if (_sources.isNotEmpty) ...[
          const SizedBox(height: 13),
          _surfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _subsectionHeader(Icons.link_rounded, _t('مصادر البحث', 'Search sources')),
              ..._sources.take(10).map((source) {
                final url = source['url'] ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.public_rounded, color: kAccent),
                  title: Text(source['title'] ?? url, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(Uri.tryParse(url)?.host ?? '', style: TextStyle(color: _mutedColor, fontSize: 10)),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 17),
                  onTap: () { if (url.isNotEmpty) _openUrl(url); },
                );
              }),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Text(_t('الأسعار والمخزون قابلان للتغيير. تأكد من صفحة المتجر وتكلفة الشحن والضمان قبل اتخاذ قرار الشراء.', 'Prices and stock can change. Confirm the listing, shipping, and warranty on the store page.'), style: TextStyle(color: _mutedColor, fontSize: 11, height: 1.6)),
      ],
    ]);
  }

  Widget _buildRarityPage() {
    final assessment = _valueText(_reportData?['rarity_assessment']).isNotEmpty ? _valueText(_reportData?['rarity_assessment']) : _extractSection('الندرة والقيمة لهواة الاقتناء');
    final rows = _raritySignals();
    return ListView(key: const PageStorageKey<String>('mango_rarity_page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
      _pageHeading(_t('الندرة وقيمة الاقتناء', 'Rarity & collector value'), _t('جدول منفصل للمؤشرات والأدلة، بعيدًا عن تخمينات السعر.', 'A dedicated evidence table, separated from price estimates.'), Icons.diamond_outlined),
      if (_result.isEmpty) _surfaceCard(child: _reportOrEmpty(text: '', icon: Icons.diamond_outlined, title: _t('تقييم الندرة غير متاح بعد', 'Rarity assessment not available yet'), hint: _t('حلّل المنتج أولًا، وسيظهر هنا تقييم الندرة وأدلته.', 'Analyze a product first to see rarity signals and evidence.')))
      else ...[
        _surfaceCard(color: appThemeMode.value == ThemeMode.light ? const Color(0xFFFFF5EC) : const Color(0xFF30231B), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _subsectionHeader(Icons.diamond_rounded, _t('التقييم العام', 'Overall assessment')),
          if (_valueText(_reportData?['rarity_score']).isNotEmpty) ...[
            Text('${_t('درجة الندرة التقديرية', 'Estimated rarity score')}: ${_valueText(_reportData?['rarity_score'])}/100', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kAccent)),
            const SizedBox(height: 8),
          ],
          if (_valueText(_reportData?['confidence_level']).isNotEmpty) ...[
            Text('${_t('مستوى الثقة', 'Confidence level')}: ${_valueText(_reportData?['confidence_level'])}', style: TextStyle(fontSize: 12, color: _mutedColor)),
            const SizedBox(height: 10),
          ],
          _markdown(assessment),
        ])),
        const SizedBox(height: 14),
        _surfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _subsectionHeader(Icons.table_chart_outlined, _t('جدول مؤشرات الندرة', 'Rarity signals table')),
          if (rows.isNotEmpty)
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              columnSpacing: 18,
              horizontalMargin: 8,
              columns: [DataColumn(label: Text(_t('المؤشر', 'Signal'))), DataColumn(label: Text(_t('الدليل', 'Evidence'))), DataColumn(label: Text(_t('التقييم', 'Assessment')))],
              rows: rows.map((row) => DataRow(cells: [
                DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 130), child: Text(_valueText(row['signal']).isEmpty ? '—' : _valueText(row['signal']), style: const TextStyle(fontWeight: FontWeight.w800)))),
                DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(_valueText(row['evidence']).isEmpty ? '—' : _valueText(row['evidence']), maxLines: 5, overflow: TextOverflow.ellipsis))),
                DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(_valueText(row['assessment']).isEmpty ? '—' : _valueText(row['assessment']), maxLines: 5, overflow: TextOverflow.ellipsis, style: TextStyle(color: kAccent, fontWeight: FontWeight.w700)))),
              ])).toList(),
            ))
          else _markdown(_extractSection('مؤشرات الندرة').isNotEmpty ? _extractSection('مؤشرات الندرة') : assessment),
        ])),
        const SizedBox(height: 14),
        _surfaceCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, color: kAccent), const SizedBox(width: 10), Expanded(child: Text(_t('تنبيه: الندرة لا تثبت من الصورة وحدها. الأفضل تأكيد رقم الإصدار، وسنة الإنتاج، وحجم الدفعة، وتوافر القطعة من مصادر موثوقة.', 'Note: rarity cannot be confirmed from a photo alone. Confirm edition, production year, batch size, and availability through reliable sources.'), style: TextStyle(color: _mutedColor, fontSize: 12, height: 1.65)))])),
      ],
    ]);
  }

  Widget _miniTag(String label, IconData icon) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(30)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: kAccent), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))]));
  }

  Widget _subsectionHeader(IconData icon, String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 18, color: kAccent)), const SizedBox(width: 9), Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)))]));
  }

  @override
  Widget build(BuildContext context) {
    final titles = <String>[_t('الرئيسية', 'Home'), _t('المنتج', 'Product'), _t('الأسعار', 'Prices'), _t('الندرة', 'Rarity')];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          Container(width: 39, height: 39, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF9A38), Color(0xFFE75D00)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 24)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('MANGO LENS', style: TextStyle(fontSize: 15, letterSpacing: 0.9, fontWeight: FontWeight.w900)), Text(titles[_selectedTab], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _mutedColor))])),
        ]),
        actions: [
          IconButton(tooltip: _t('سجل الفحص', 'Scan history'), onPressed: _openHistory, icon: Badge(isLabelVisible: _history.isNotEmpty, label: Text('${_history.length}'), child: const Icon(Icons.history_rounded))),
          IconButton(tooltip: _t('الإعدادات', 'Settings'), onPressed: _settings, icon: const Icon(Icons.settings_outlined)),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: _selectedTab, children: [_buildHomePage(), _buildProductPage(), _buildPricesPage(), _buildRarityPage()])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        backgroundColor: _surfaceColor,
        indicatorColor: kAccent.withValues(alpha: 0.15),
        elevation: 0,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: _t('الرئيسية', 'Home')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2_rounded), label: _t('المنتج', 'Product')),
          NavigationDestination(icon: const Icon(Icons.price_change_outlined), selectedIcon: const Icon(Icons.price_change_rounded), label: _t('الأسعار', 'Prices')),
          NavigationDestination(icon: const Icon(Icons.diamond_outlined), selectedIcon: const Icon(Icons.diamond_rounded), label: _t('الندرة', 'Rarity')),
        ],
      ),
    );
  }
}