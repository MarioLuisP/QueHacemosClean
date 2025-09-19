import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'src/providers/favorites_provider.dart';
import 'src/providers/simple_home_provider.dart';
import 'src/providers/auth_provider.dart';
import 'src/themes/themes.dart';
import 'src/navigation/bottom_nav.dart';
import 'src/providers/notifications_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'src/services/daily_task_manager.dart';
import 'src/services/first_install_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/sync/sync_service.dart';
import 'src/models/user_preferences.dart';
import 'src/services/notification_service.dart';
import 'src/services/notification_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['action'] == 'daily_recovery') {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final hasFavorites = prefs.getBool('has_favorites_$today') ?? false;

      if (hasFavorites) {
        final lastHttpCall = prefs.getInt('last_http_notification') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - lastHttpCall > 60000) {
          await _sendNotificationRequest();
          await prefs.setInt('last_http_notification', now);
        }
      }
    } catch (e) {
      // Error handling silencioso
    }
  }
}
Future<void> _sendNotificationRequest() async {
  try {

    final url = dotenv.env['CLOUD_FUNCTION_URL'];


    if (url == null || url.isEmpty) {

      return;
    }


    final response = await http.post(Uri.parse(url));

    if (response.statusCode == 200) {

    } else {

    }
  } catch (e) {

  }
}
Future<void> _checkAndReinitializeFCMIfNeeded() async {
  try {

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.buildNumber;


    final lastFCMVersion = await UserPreferences.getLastFCMInitVersion();



    if (lastFCMVersion != currentVersion) {


      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseMessaging.instance.subscribeToTopic('eventos_cordoba');
        await UserPreferences.setLastFCMInitVersion(currentVersion);

      }
    } else {

    }
  } catch (e) {

  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es_ES';
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initializeAnonymousAuth();

  tz.initializeTimeZones();

  runApp(const MyApp());
}

Future<void> _initializeAnonymousAuth() async {
  try {

  } catch (e) {

  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [

        ChangeNotifierProvider(
          create: (context) => AuthProvider(),
        ),

        ChangeNotifierProvider(
          create: (context) => SimpleHomeProvider(),
        ),

        ChangeNotifierProvider(
          create: (context) => FavoritesProvider(),
        ),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: const _AppContent(),
    );
  }
}

class _AppContent extends StatefulWidget {
  const _AppContent();

  @override
  State<_AppContent> createState() => _AppContentState();
}

class _AppContentState extends State<_AppContent> with WidgetsBindingObserver {
  bool _isInitialized = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuthInBackground();
    });
  }

  Future<void> _initializeApp() async {
    try {

      final firstInstallService = FirstInstallService();
      final needsFirstInstall = await firstInstallService.needsFirstInstall();

      if (needsFirstInstall) {

        await firstInstallService.performFirstInstall();
      }

      await _performNormalInitialization();

    } catch (e) {

      await _performNormalInitialization();
    }
  }


  Future<void> _performNormalInitialization() async {

    final simpleHomeProvider = Provider.of<SimpleHomeProvider>(context, listen: false);
    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);

    try {
      await simpleHomeProvider.initialize();
      await favoritesProvider.init();

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final isConfigured = await UserPreferences.getNotificationsReady();
        if (isConfigured) {
          await NotificationService.initialize();
          await _checkAndReinitializeFCMIfNeeded();

        }
      });

      final dailyTaskManager = DailyTaskManager();
      await dailyTaskManager.initialize();

      simpleHomeProvider.setupFavoritesSync(favoritesProvider);
      SyncService().setHomeProvider(simpleHomeProvider);
      setState(() {
        _isInitialized = true;
      });


      WidgetsBinding.instance.addPostFrameCallback((_) {

        DailyTaskManager().checkOnAppOpen();

        NotificationManager().checkOnAppOpen();
      });


    } catch (e) {

      setState(() {
        _isInitialized = true;
      });
    }
  }


  void _initializeAuthInBackground() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);


    authProvider.initializeAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DailyTaskManager().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      DailyTaskManager().checkOnAppOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return Consumer<SimpleHomeProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es', ''), Locale('en', '')],
          title: 'Eventos Córdoba - Cache Test',
          theme: AppThemes.themes[provider.theme] ?? AppThemes.themes['normal']!,
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}