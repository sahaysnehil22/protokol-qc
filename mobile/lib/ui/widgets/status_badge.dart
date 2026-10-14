import 'package:flutter/material.dart';
import '../../core/constants.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isFinding;

  const StatusBadge({
    super.key,
    required this.status,
    this.isFinding = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'conforme':
      case 'verificado':
        bg = AppColors.conformeBg;
        fg = AppColors.conforme;
        label = isFinding ? 'VERIFICADO' : 'CONFORME';
        break;
      case 'observado':
      case 'no_conforme':
      case 'abierto':
        bg = AppColors.noConformeBg;
        fg = AppColors.noConforme;
        label = isFinding ? 'ABIERTO' : 'OBSERVADO';
        break;
      case 'en_proceso':
      case 'en_revision':
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        label = isFinding ? 'EN PROCESO' : 'EN REVISIÓN';
        break;
      case 'cerrado_con_evidencia':
        bg = AppColors.infoBg;
        fg = AppColors.info;
        label = 'SUBSANADO (EVIDENCIA)';
        break;
      case 'borrador':
      default:
        bg = const Color(0xFFEDF2F7);
        fg = AppColors.textMuted;
        label = status.toUpperCase().replaceAll('_', ' ');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
