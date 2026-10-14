import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/pdf_service.dart';
import '../../services/share_service.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Inspection inspection;
  final Project project;
  final String locationPath;
  final InspectionTemplate template;

  const PdfPreviewScreen({
    super.key,
    required this.inspection,
    required this.project,
    required this.locationPath,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Protocolo ${inspection.code}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            const Text(
              'Documento Oficial de Liberación',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.primary),
            tooltip: 'Compartir por WhatsApp',
            onPressed: () async {
              final pdfBytes = await PdfService.generateInspectionPdf(
                inspection: inspection,
                project: project,
                locationPath: locationPath,
                template: template,
              );
              await ShareService.sharePdf(
                pdfBytes: pdfBytes,
                filename: '${inspection.code}.pdf',
                subject: '${project.name} - Protocolo ${inspection.code}',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sticky WhatsApp CTA bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFE6FFFA),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF234E52), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Listo para envío inmediato a ITO, Residencia o Grupo WhatsApp de Obra',
                    style: TextStyle(color: Color(0xFF234E52), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pdfBytes = await PdfService.generateInspectionPdf(
                      inspection: inspection,
                      project: project,
                      locationPath: locationPath,
                      template: template,
                    );
                    await ShareService.sharePdf(
                      pdfBytes: pdfBytes,
                      filename: '${inspection.code}.pdf',
                      subject: '${project.name} - Protocolo ${inspection.code}',
                    );
                  },
                  icon: const Icon(Icons.share, size: 14),
                  label: const Text('ENVIAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),

          // Interactive PDF Viewer
          Expanded(
            child: PdfPreview(
              build: (format) => PdfService.generateInspectionPdf(
                inspection: inspection,
                project: project,
                locationPath: locationPath,
                template: template,
              ),
              canChangeOrientation: false,
              canChangePageFormat: false,
              allowSharing: true,
              allowPrinting: true,
              pdfFileName: '${inspection.code}.pdf',
              previewPageMargin: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
