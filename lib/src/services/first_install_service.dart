// lib/src/services/first_install_service.dart

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/firestore_client.dart';
import '../data/repositories/event_repository.dart';
import '../providers/notifications_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../cache/event_cache_service.dart';
import '../sync/sync_service.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_preferences.dart';

class FirstInstallService {
  static final FirstInstallService _instance = FirstInstallService._internal();
  factory FirstInstallService() => _instance;

  FirstInstallService._internal() {
    SyncService.onSyncComplete.listen((result) {
      if (result.success && result.eventsAdded > 0) {
        _refreshSimpleHomeProvider();
      }
    });
  }

  static const String _firstInstallKey = 'first_install_completed';

  final FirestoreClient _firestoreClient = FirestoreClient();
  final EventRepository _eventRepository = EventRepository();
  final NotificationsProvider _notificationsProvider = NotificationsProvider.instance;

  bool _isRunning = false;

  Future<bool> needsFirstInstall() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_firstInstallKey) ?? false);
  }

  Future<FirstInstallResult> performFirstInstall() async {
    if (_isRunning) {
      return FirstInstallResult.alreadyRunning();
    }

    _isRunning = true;

    try {

      if (!await needsFirstInstall()) {
        return FirstInstallResult.alreadyCompleted();
      }

      await _prepareTechnicalSetup();

      final completeBatches = await _downloadInitialContent();

      await _processInitialData(completeBatches);

      await _markFirstInstallCompleted();
      await _setInitialSyncTimestamp();

      final totalEvents = completeBatches.fold<int>(0, (sum, batch) {
        final eventos = (batch['eventos'] as List<dynamic>?) ?? [];
        return sum + eventos.length;
      });

      await _notifySuccess(totalEvents);

      return FirstInstallResult.success(eventsDownloaded: totalEvents);

    } catch (e) {
      await _notifyError(e);
      return FirstInstallResult.error(e.toString());
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _setInitialSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_timestamp', DateTime.now().toIso8601String());
  }
  Future<void> _prepareTechnicalSetup() async {

    await _eventRepository.getTotalEvents();
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt < 33) {
        try {
          final existingToken = await FirebaseMessaging.instance.getToken();

          if (existingToken != null) {
            await FirebaseMessaging.instance.subscribeToTopic('eventos_cordoba');
          } else {
            await FirebaseMessaging.instance.requestPermission();
            final token = await FirebaseMessaging.instance.getToken();
            await FirebaseMessaging.instance.subscribeToTopic('eventos_cordoba');
          }

          await UserPreferences.setNotificationsReady(true);
        } catch (e) {
        }
      }
    }

  }

  Future<List<Map<String, dynamic>>> _downloadInitialContent() async {
    const int maxRetries = 3;
    const Duration retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {

        final events = await _downloadFromFirestore();

        if (events.isEmpty) {
          throw Exception('No se encontraron eventos en el servidor');
        }

        return events;

      } catch (e) {

        if (attempt == maxRetries) {
          throw NetworkException('Error de conexión después de $maxRetries intentos: $e');
        }

        await Future.delayed(retryDelay);
      }
    }

    throw Exception('Error inesperado en descarga');
  }

  Future<List<Map<String, dynamic>>> _downloadFromFirestore() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('eventos_lotes')
          .orderBy('metadata.fecha_subida', descending: true)
          .limit(10)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return [];
      }

      final completeBatches = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      final newBatchVersion = completeBatches.first['metadata']?['nombre_lote'] as String? ?? 'multiple';

      final totalEvents = completeBatches.fold<int>(0, (sum, batch) {
        final eventos = (batch['eventos'] as List<dynamic>?) ?? [];
        return sum + eventos.length;
      });

      await _eventRepository.updateSyncInfo(
        batchVersion: newBatchVersion,
        totalEvents: totalEvents,
      );

      return completeBatches;

    } catch (e) {
      rethrow;
    }
  }

  Future<void> _processInitialData(List<Map<String, dynamic>> completeBatches) async {
    if (completeBatches.isEmpty) {
      return;
    }

    completeBatches.sort((a, b) {
      final fechaA = a['metadata']?['fecha_subida'] as String? ?? '';
      final fechaB = b['metadata']?['fecha_subida'] as String? ?? '';
      return fechaA.compareTo(fechaB);
    });

    int totalEventosInsertados = 0;
    int totalDuplicadosRemovidos = 0;
    int totalEventosLimpiados = 0;
    int totalFavoritosLimpiados = 0;

    for (int i = 0; i < completeBatches.length; i++) {
      final batch = completeBatches[i];
      final metadata = batch['metadata'] as Map<String, dynamic>?;
      final eventos = (batch['eventos'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];

      final nombreLote = metadata?['nombre_lote'] ?? 'lote_${i + 1}';
      final fechaSubida = metadata?['fecha_subida'] ?? 'unknown';

      if (eventos.isEmpty) {
        continue;
      }

      await _eventRepository.insertEvents(eventos);
      totalEventosInsertados += eventos.length;

      final duplicadosRemovidos = await _eventRepository.removeDuplicatesByCodes();
      totalDuplicadosRemovidos += duplicadosRemovidos;

      final cleanupResults = await _eventRepository.cleanOldEvents();
      final eventosLimpiados = cleanupResults['normalEvents'] ?? 0;
      final favoritosLimpiados = cleanupResults['favoriteEvents'] ?? 0;

      totalEventosLimpiados += eventosLimpiados;
      totalFavoritosLimpiados += favoritosLimpiados;

    }

    await _refreshSimpleHomeProvider();
  }

  Future<void> _markFirstInstallCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstInstallKey, true);
  }

  Future<void> _notifySuccess(int eventsCount) async {
    await _notificationsProvider.addNotification(
      title: '🎭 ¡App lista para usar!',
      message: 'Se configuraron $eventsCount eventos culturales de Córdoba',
      type: 'first_install_complete',
    );
  }

  Future<void> _notifyError(dynamic error) async {
    String title;
    String message;

    if (error is NetworkException) {
      title = '📡 Sin conexión a internet';
      message = 'No se pudieron descargar los eventos. La app intentará automáticamente más tarde';
    } else {
      title = '⚠️ Error de configuración';
      message = 'Error interno de la app, se reintentará en la próxima apertura';
    }

    await _notificationsProvider.addNotification(
      title: title,
      message: message,
      type: 'first_install_error',
    );
  }

  Future<Map<String, dynamic>> getInstallationStatus() async {
    final isCompleted = !await needsFirstInstall();

    return {
      'completed': isCompleted,
      'running': _isRunning,
      'needsInstall': await needsFirstInstall(),
    };
  }

  Future<void> resetFirstInstallFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstInstallKey);
  }
  Future<void> _refreshSimpleHomeProvider() async {
    try {

      final EventCacheService cacheService = EventCacheService();
      await cacheService.reloadCache();

    } catch (e) {
    }
  }
}

class FirstInstallResult {
  final bool success;
  final String? error;
  final int eventsDownloaded;
  final FirstInstallResultType type;

  FirstInstallResult._({
    required this.success,
    this.error,
    this.eventsDownloaded = 0,
    required this.type,
  });

  factory FirstInstallResult.success({required int eventsDownloaded}) =>
      FirstInstallResult._(
        success: true,
        eventsDownloaded: eventsDownloaded,
        type: FirstInstallResultType.success,
      );

  factory FirstInstallResult.alreadyCompleted() =>
      FirstInstallResult._(
        success: true,
        type: FirstInstallResultType.alreadyCompleted,
      );

  factory FirstInstallResult.alreadyRunning() =>
      FirstInstallResult._(
        success: false,
        error: 'Primera instalación ya en progreso',
        type: FirstInstallResultType.alreadyRunning,
      );

  factory FirstInstallResult.error(String error) =>
      FirstInstallResult._(
        success: false,
        error: error,
        type: FirstInstallResultType.error,
      );
}

enum FirstInstallResultType {
  success,
  alreadyCompleted,
  alreadyRunning,
  error
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}