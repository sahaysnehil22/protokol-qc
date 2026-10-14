import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/sync_manager.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SyncManager.instance,
      builder: (context, _) {
        final sync = SyncManager.instance;

        if (sync.isSyncing) {
          return Container(
            color: AppColors.infoBg,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: 8),
            child: Row(
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.info),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sincronizando protocolos y hallazgos con el servidor...',
                    style: TextStyle(color: AppColors.info, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }

        if (!sync.isOnline || sync.pendingCount > 0) {
          return Container(
            color: sync.isOnline ? AppColors.warningBg : const Color(0xFFFED7D7),
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: 8),
            child: Row(
              children: [
                Icon(
                  sync.isOnline ? Icons.cloud_upload_outlined : Icons.cloud_off_rounded,
                  size: 18,
                  color: sync.isOnline ? AppColors.warning : AppColors.noConforme,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sync.isOnline
                        ? '${sync.pendingCount} cambio(s) pendientes de sincronización'
                        : 'Modo Offline: Datos guardados localmente (${sync.pendingCount} pendientes)',
                    style: TextStyle(
                      color: sync.isOnline ? AppColors.warning : AppColors.noConforme,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (sync.isOnline)
                  TextButton(
                    onPressed: () => sync.syncNow(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('SUBIR AHORA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
