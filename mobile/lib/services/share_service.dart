import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

class ShareService {
  static Future<void> sharePdf({
    required Uint8List pdfBytes,
    required String filename,
    required String subject,
  }) async {
    final xFile = XFile.fromData(
      pdfBytes,
      name: filename,
      mimeType: 'application/pdf',
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: 'Adjunto Protocolo Oficial de Control de Calidad: $subject',
        subject: subject,
      ),
    );
  }

  static Future<void> shareFindingViaWhatsApp(Finding finding) async {
    final severityEmoji = finding.severity == 'critico' ? '🚨 [CRÍTICO]' : (finding.severity == 'moderado' ? '⚠️ [MODERADO]' : 'ℹ️ [LEVE]');
    final text = '''
*PROTOKOL QC - REPORTE DE NO CONFORMIDAD / HALLAZGO*
$severityEmoji
*Código:* ${finding.code}
*Título:* ${finding.title}
*Proyecto:* ${finding.projectName ?? 'Edificio Las Palmeras'}
*Ubicación:* ${finding.locationName ?? 'En obra'}
*Especialidad:* ${finding.assignedTrade}
*Fecha Límite:* ${finding.dueDate}
*Estado:* ${finding.status.toUpperCase()}

*Descripción del Defecto:*
${finding.description}

*Instrucciones de Subsanación:*
El contratista asignado debe subsanar el defecto antes de la fecha límite y cargar la fotografía de evidencia en la app Protokol QC para la verificación de Calidad/Residencia.
''';

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Hallazgo: ${finding.code} - ${finding.title}',
      ),
    );
  }
}
