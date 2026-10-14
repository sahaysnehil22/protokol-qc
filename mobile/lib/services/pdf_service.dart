import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/models.dart';

class PdfService {
  static Future<Uint8List> generateInspectionPdf({
    required Inspection inspection,
    required Project project,
    required String locationPath,
    required InspectionTemplate template,
    String? companyName,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final nowFormatted = dateFormat.format(DateTime.now());

    final primaryColor = PdfColor.fromHex('#D9531E');
    final darkNeutral = PdfColor.fromHex('#1A202C');
    final borderGray = PdfColor.fromHex('#CBD5E0');
    final bgLight = PdfColor.fromHex('#F7FAFC');
    final conformeColor = PdfColor.fromHex('#22543D');
    final noConformeColor = PdfColor.fromHex('#9B2C2C');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: borderGray, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      (companyName ?? 'INMOBILIARIA & CONSTRUCTORA SAN MARTÍN S.A.C.').toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'PROTOCOLO OFICIAL DE CONTROL DE CALIDAD',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: darkNeutral,
                      ),
                    ),
                    pw.Text(
                      'Norma Técnica Peruana (NTE E.060 / RNE)',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: bgLight,
                    border: pw.Border.all(color: borderGray),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'CÓDIGO: ${inspection.code}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkNeutral),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'ESTADO: ${inspection.status.toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: inspection.status == 'conforme' ? conformeColor : (inspection.status == 'observado' ? noConformeColor : primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderGray, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Protokol QC Perú — Registro digital inmutable con hash de auditoría',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),

          // Project & Inspection Metadata Box
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: bgLight,
              border: pw.Border.all(color: borderGray),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: _buildMetaField('Proyecto', '${project.name} (${project.code})'),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: _buildMetaField('Ubicación Detallada', locationPath),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildMetaField('Partida / Plantilla', '${template.title} [${template.code}]'),
                    ),
                    pw.Expanded(
                      child: _buildMetaField('Fecha de Vaciado / Ejecución', inspection.pourDate ?? 'No aplica'),
                    ),
                    pw.Expanded(
                      child: _buildMetaField('Guía Mixer / Lote', inspection.batchNumber ?? 'S/N'),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildMetaField('Residente de Obra', project.residentName ?? 'Ing. Residente CIP'),
                    ),
                    pw.Expanded(
                      child: _buildMetaField('Supervisor / ITO', project.itoName ?? 'Ing. Inspector'),
                    ),
                    pw.Expanded(
                      child: _buildMetaField('Fecha y Hora Registro', nowFormatted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // Technical Checklist Section Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: darkNeutral,
            child: pw.Text(
              'VERIFICACIÓN DE REQUISITOS TÉCNICOS Y TOLERANCIAS NORMATIVAS',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),

          // Checklist Items Table
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: borderGray, width: 0.5),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkNeutral),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#EDF2F7')),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            columnWidths: {
              0: const pw.FixedColumnWidth(40), // Item code
              1: const pw.FlexColumnWidth(3),   // Question text
              2: const pw.FlexColumnWidth(2),   // Specification / Tolerance
              3: const pw.FixedColumnWidth(70), // Status
              4: const pw.FlexColumnWidth(2),   // Observation / Value
            },
            headers: ['ÍTEM', 'DESCRIPCIÓN DEL REQUISITO', 'TOLERANCIA / NORMA', 'ESTADO', 'MEDICIÓN / NOTA'],
            data: template.items.map((item) {
              final answer = inspection.answers.firstWhere(
                (a) => a.itemId == item.id,
                orElse: () => InspectionAnswer(id: '', inspectionId: inspection.id, itemId: item.id),
              );

              String tolerance = 'Criterio visual';
              if (item.toleranceMin != null && item.toleranceMax != null) {
                tolerance = '${item.toleranceMin} - ${item.toleranceMax} ${item.unit ?? ''}';
              }

              String statusStr = answer.status.replaceAll('_', ' ').toUpperCase();
              String valNote = '';
              if (answer.numericValue != null) {
                valNote = '${answer.numericValue} ${item.unit ?? ''}';
              }
              if (answer.observationText != null && answer.observationText!.isNotEmpty) {
                valNote += (valNote.isNotEmpty ? ' | ' : '') + answer.observationText!;
              }

              return [
                item.code,
                item.questionText + (item.isCritical ? ' (CRÍTICO)' : ''),
                tolerance,
                statusStr,
                valNote.isEmpty ? 'Conforme s/obs' : valNote,
              ];
            }).toList(),
          ),

          if (inspection.generalNotes != null && inspection.generalNotes!.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderGray),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('OBSERVACIONES GENERALES / CUADERNO DE OBRA:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text(inspection.generalNotes!, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ],

          pw.SizedBox(height: 24),

          // Signatures Section
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: PdfColor.fromHex('#EDF2F7'),
            child: pw.Text(
              'CONFORMIDAD Y FIRMAS DE LIBERACIÓN',
              style: pw.TextStyle(color: darkNeutral, fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSignatureBox('ING. ESPECIALISTA DE CALIDAD', 'Área de Control de Calidad', 'Firma y Sello CIP'),
              _buildSignatureBox('ING. RESIDENTE DE OBRA', project.residentName ?? 'Residencia de Obra', 'Firma y Sello CIP'),
              _buildSignatureBox('SUPERVISIÓN TÉCNICA (ITO)', project.itoName ?? 'Supervisión Externa', 'Firma y Sello'),
              _buildSignatureBox('CONTRATISTA RESPONSABLE', 'Subcontratista de Especialidad', 'Firma y Sello'),
            ],
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildMetaField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 1),
        pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1A202C'))),
      ],
    );
  }

  static pw.Widget _buildSignatureBox(String role, String name, String subtitle) {
    return pw.Container(
      width: 120,
      child: pw.Column(
        children: [
          pw.Container(
            height: 45,
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey500, width: 1)),
            ),
            child: pw.Center(
              child: pw.Text('[FIRMADO DIGITALMENTE]', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(role, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
          pw.Text(name, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey800), textAlign: pw.TextAlign.center),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600), textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }
}
