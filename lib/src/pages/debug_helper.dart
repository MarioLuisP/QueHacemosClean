import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/event_repository.dart';
import '../services/daily_task_manager.dart';
import '../services/notification_manager.dart';
import '../utils/dimens.dart';
import '../services/weekly_prompt_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class DebugTestingHelper {

  // ========== MÉTODO PRINCIPAL PARA GENERAR LA CARD ==========
  static Widget buildDeveloperCard(BuildContext context) {
    return Card(
      elevation: AppDimens.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔧 Desarrollador',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimens.paddingMedium),
            _buildDebugButton(
              context,
              'RESET PRIMERA INSTALACIÓN',
              '🔄 Marcar app como no inicializada (4 SP keys)',
              Colors.blue,
                  () => _resetFirstInstallation(context),
            ),
            const SizedBox(height: AppDimens.paddingSmall),
            _buildDebugButton(
              context,
              'LIMPIAR BASE DE DATOS',
              '⚠️ Borra todos los eventos guardados',
              Colors.red,
                  () => _clearDatabase(context),
            ),
            const SizedBox(height: AppDimens.paddingSmall),
            _buildDebugButton(
              context,
              'VER BASE DE DATOS',
              '📊 Mostrar eventos guardados y estado de sync',
              Colors.green,
                  () => _showDatabaseInfo(context),
            ),
            const SizedBox(height: AppDimens.paddingSmall),
            _buildDebugButton(
              context,
              'ESTADÍSTICAS',
              '📈 Conteo por categorías y resumen',
              Colors.orange,
                  () => _showEventStats(context),
            ),
            const SizedBox(height: AppDimens.paddingSmall),
            _buildDebugButton(
              context,
              'MARCAR SYNC VENCIDA',
              '⏰ Setear timestamp -25h para forzar recovery',
              Colors.teal,
                  () => _markSyncExpired(context),
            ),
            const SizedBox(height: AppDimens.paddingSmall),
            _buildDebugButton(
              context,
              'VER ESTADO TIMER',
              '⏱️ Mostrar estado del timer de conectividad (20min)',
              Colors.indigo,
                  () => _showTimerState(context),
            ),
            const SizedBox(height: AppDimens.paddingSmall),
            _buildDebugButton(
              context,
              'TEST NOTIFIC INMEDIATO',
              '🔔 Ejecutar recovery de notificaciones directo',
              Colors.teal,
                  () => _testNotificationRecovery(context),
            ),
            const SizedBox(height: AppDimens.paddingSmall),
            _buildDebugButton(
              context,
              'MARCAR NOTIF VENCIDA',
              '🔄 Resetear para testing recovery automático',
              Colors.purple,
                  () async {
                await NotificationManager().resetRecoveryTimestamp();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Timestamp reseteado - mata app y reabre para probar')),
                );
              },
            ),
            const SizedBox(height: AppDimens.paddingSmall),
            _buildDebugButton(
              context,
              'TOGGLE FAVORITOS HOY',
              'Cambiar estado has_favorites_today para testing push',
              Colors.cyan,
                  () => _toggleFavoritesToday(context),
            ),
            const SizedBox(height: AppDimens.paddingSmall),
            _buildDebugButton(
              context,
              'TEST PROMPT TRIGGERS',
              'Evaluar si se activarían prompts de login y notificaciones',
              Colors.amber,
                  () => _testPromptTriggers(context),
            ),
          ],
        ),
      ),
    );
  }

  // ========== MÉTODOS HELPER ==========
  static Widget _buildDebugButton(
      BuildContext context,
      String title,
      String subtitle,
      Color color,
      VoidCallback onPressed,
      ) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(AppDimens.paddingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: color.withAlpha(179), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== MÉTODOS DE FUNCIONALIDAD ==========
  static Future<void> _resetFirstInstallation(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔄 Reseteando primera instalación...')),
      );

      final prefs = await SharedPreferences.getInstance();

      // Borrar las keys principales
      await prefs.remove('first_install_completed');
      await prefs.remove('last_sync_timestamp');
      await prefs.remove('last_notification_timestamp');
      await prefs.setBool('app_initialized', false);

      print('🔄 Flag primera instalación borrado');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Reset completo - Mata app y abre para probar primera instalación'),
          duration: Duration(seconds: 4),
        ),
      );

      print('🧪 RESET: App marcada como no inicializada');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error en reset: $e')),
      );
    }
  }

  static Future<void> _clearDatabase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Limpiar Base de Datos'),
          content: const Text(
            '¿Estás seguro? Se borrarán todos los eventos guardados. Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Borrar Todo'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final repository = EventRepository();
        await repository.clearAllData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Base de datos limpiada')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error limpiando: $e')),
        );
      }
    }
  }

  static Future<void> _showDatabaseInfo(BuildContext context) async {
    try {
      final repository = EventRepository();
      final eventos = await repository.getAllEvents();
      final syncInfo = await repository.getSyncInfo();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📊 Estado de la Base de Datos'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📦 Total eventos: ${eventos.length}'),
                Text(
                  '🕘 Última sync: ${syncInfo?['last_sync'] ?? 'Nunca'}',
                ),
                Text(
                  '🏷️ Versión lote: ${syncInfo?['batch_version'] ?? 'N/A'}',
                ),
                const SizedBox(height: 16),
                const Text(
                  '📋 Últimos 5 eventos:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...eventos
                    .take(5)
                    .map(
                      (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${e['title']} (${e['date']})'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  static Future<void> _showEventStats(BuildContext context) async {
    try {
      final repository = EventRepository();
      final eventos = await repository.getAllEvents();
      final favoritos = await repository.getAllFavorites();

      final stats = <String, int>{};
      for (var evento in eventos) {
        final tipo = evento['type'] ?? 'sin_tipo';
        stats[tipo] = (stats[tipo] ?? 0) + 1;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📈 Estadísticas'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📊 Total eventos: ${eventos.length}'),
                Text('⭐ Favoritos: ${favoritos.length}'),
                const SizedBox(height: 16),
                const Text(
                  '📋 Por categoría:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...stats.entries.map(
                      (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${entry.key}: ${entry.value} eventos'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  static Future<void> _markSyncExpired(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏰ Marcando sync como vencida...')),
      );

      final prefs = await SharedPreferences.getInstance();
      final expiredTime = DateTime.now().subtract(const Duration(hours: 25));
      await prefs.setString('last_sync_timestamp', expiredTime.toIso8601String());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sync marcada como vencida - Mata app y abre para probar recovery'),
          duration: Duration(seconds: 4),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error marcando sync vencida: $e')),
      );
      print('❌ ERROR EXPIRED: $e');
    }
  }

  static Future<void> _showTimerState(BuildContext context) async {
    try {
      final timerState = DailyTaskManager().getTimerState();
      final debugState = DailyTaskManager().getDebugState();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⏱️ Estado del Timer'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timerState['status'] ?? 'Estado desconocido',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Text('🔄 Timer activo: ${timerState['active'] ? 'SÍ' : 'NO'}'),
                if (timerState['interval_minutes'] != null)
                  Text('⏰ Intervalo: ${timerState['interval_minutes']} minutos'),
                Text('🕐 Hora actual: ${debugState['current_time']}'),
                if (timerState['timer_valid_window'] != null)
                  Text('✅ Ventana válida: ${timerState['timer_valid_window']}'),
                const SizedBox(height: 12),
                const Text(
                  '📝 Notas:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('• Timer solo activo si hora < 1am'),
                const Text('• Se cancela con sync exitoso'),
                const Text('• Se cancela al salir de app'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error mostrando estado: $e')),
      );
    }
  }

  static Future<void> _testNotificationRecovery(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏳ Ejecutando recovery de notificaciones...')),
      );

      await NotificationManager().testExecuteRecovery();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Recovery de notificaciones ejecutado'),
          duration: Duration(seconds: 4),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> _toggleFavoritesToday(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final currentValue = prefs.getBool('has_favorites_$today') ?? false;
      final newValue = !currentValue;

      await prefs.setBool('has_favorites_$today', newValue);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Favoritos HOY: ${newValue ? "SÍ" : "NO"}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  static Future<void> _testPromptTriggers(BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final loginPrompt = await WeeklyPromptService.shouldShowLoginPrompt(authProvider);
      final notifPrompt = await WeeklyPromptService.shouldShowNotificationPrompt();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login: ${loginPrompt ? "SÍ" : "NO"}, Notif: ${notifPrompt ? "SÍ" : "NO"}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error evaluando prompts: $e')),
      );
    }
  }
}