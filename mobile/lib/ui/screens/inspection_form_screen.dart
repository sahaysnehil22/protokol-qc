import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../data/local_db.dart';
import '../../data/sync_manager.dart';
import 'pdf_preview_screen.dart';

class InspectionFormScreen extends StatefulWidget {
  final Project project;
  final String locationId;
  final String locationName;
  final String locationPath;
  final InspectionTemplate template;
  final User currentUser;
  final Inspection? existingInspection;

  const InspectionFormScreen({
    super.key,
    required this.project,
    required this.locationId,
    required this.locationName,
    required this.locationPath,
    required this.template,
    required this.currentUser,
    this.existingInspection,
  });

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  late String _inspectionId;
  late String _inspectionCode;
  final _pourDateController = TextEditingController(text: '15/10/2026');
  final _batchNumberController = TextEditingController(text: 'MIX-UNICON-9421');
  final _weatherController = TextEditingController(text: 'Soleado 21°C');
  final _generalNotesController = TextEditingController();

  // Answers Map: itemId -> InspectionAnswer
  final Map<String, InspectionAnswer> _answers = {};
  bool _isSaving = false;
  bool _isSignedByInspector = true;
  bool _isSignedByResident = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingInspection != null) {
      _inspectionId = widget.existingInspection!.id;
      _inspectionCode = widget.existingInspection!.code;
      _pourDateController.text = widget.existingInspection!.pourDate ?? '';
      _batchNumberController.text = widget.existingInspection!.batchNumber ?? '';
      _weatherController.text = widget.existingInspection!.weather ?? '';
      _generalNotesController.text = widget.existingInspection!.generalNotes ?? '';
      for (final a in widget.existingInspection!.answers) {
        _answers[a.itemId] = a;
      }
    } else {
      _inspectionId = const Uuid().v4();
      final randomNum = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000));
      _inspectionCode = 'PROT-2026-$randomNum';

      // Pre-initialize answers for all template items
      for (final item in widget.template.items) {
        _answers[item.id] = InspectionAnswer(
          id: const Uuid().v4(),
          inspectionId: _inspectionId,
          itemId: item.id,
          status: 'conforme', // Default positive baseline
        );
      }
    }
  }

  // Count items by status
  int get _failedCount => _answers.values.where((a) => a.status == 'no_conforme').length;
  int get _conformeCount => _answers.values.where((a) => a.status == 'conforme').length;

  Future<void> _saveInspection({required bool finalize}) async {
    setState(() => _isSaving = true);

    try {
      final inspectionStatus = finalize
          ? (_failedCount > 0 ? 'observado' : 'conforme')
          : 'borrador';

      final inspection = Inspection(
        id: _inspectionId,
        projectId: widget.project.id,
        locationId: widget.locationId,
        templateId: widget.template.id,
        code: _inspectionCode,
        status: inspectionStatus,
        pourDate: _pourDateController.text.trim(),
        batchNumber: _batchNumberController.text.trim(),
        weather: _weatherController.text.trim(),
        generalNotes: _generalNotesController.text.trim(),
        projectName: widget.project.name,
        locationName: widget.locationName,
        templateTitle: widget.template.title,
        inspectorName: widget.currentUser.fullName,
        answers: _answers.values.toList(),
      );

      // 1. Save locally in SQLite
      await LocalDatabase.instance.saveInspection(inspection);

      // 2. Auto-promote failed items to Hallazgos (Snags)
      final List<Finding> generatedFindings = [];
      if (finalize && _failedCount > 0) {
        for (final item in widget.template.items) {
          final answer = _answers[item.id];
          if (answer != null && answer.status == 'no_conforme') {
            final findingId = const Uuid().v4();
            final randomCode = 100 + (DateTime.now().millisecondsSinceEpoch % 900);
            final finding = Finding(
              id: findingId,
              projectId: widget.project.id,
              inspectionId: _inspectionId,
              locationId: widget.locationId,
              code: 'HAL-2026-$randomCode',
              title: 'No Conformidad: ${item.questionText}',
              description: answer.observationText ?? 'Falla de tolerancia o criterio en ítem ${item.code}',
              severity: item.isCritical ? 'critico' : 'moderado',
              status: 'abierto',
              assignedTrade: widget.template.family == 'acero'
                  ? 'Fierrería'
                  : (widget.template.family == 'acabados' ? 'Pintura y Acabados' : 'Estructuras Concreto'),
              dueDate: DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0, 10),
              projectName: widget.project.name,
              locationName: widget.locationName,
            );
            generatedFindings.add(finding);

            // Queue finding creation operation
            await LocalDatabase.instance.queueOperation(
              entityType: 'finding',
              entityId: finding.id,
              operation: 'CREATE',
              payload: finding.toJson(),
            );
          }
        }
        await LocalDatabase.instance.saveFindings(generatedFindings);
      }

      // 3. Queue inspection sync operation
      await LocalDatabase.instance.queueOperation(
        entityType: 'inspection',
        entityId: inspection.id,
        operation: 'CREATE',
        payload: {
          ...inspection.toJson(),
          'answers': _answers.values.map((a) => a.toJson()).toList(),
        },
      );

      // Trigger background sync attempt
      SyncManager.instance.syncNow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              finalize
                  ? 'Protocolo $_inspectionCode guardado y liberado con éxito.'
                  : 'Borrador guardado localmente.',
            ),
            backgroundColor: AppColors.conforme,
          ),
        );

        if (finalize) {
          // Open PDF Preview & WhatsApp share
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PdfPreviewScreen(
                inspection: inspection,
                project: widget.project,
                locationPath: widget.locationPath,
                template: widget.template,
              ),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppColors.noConforme),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group template items by section
    final Map<String, List<TemplateItem>> sections = {};
    for (final item in widget.template.items) {
      sections.putIfAbsent(item.section, () => []).add(item);
    }

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
              _inspectionCode,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            Text(
              widget.template.title,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _saveInspection(finalize: false),
            child: const Text('BORRADOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sticky Location & Status summary strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primaryLight,
            child: Row(
              children: [
                const Icon(Icons.place, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.locationPath,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _failedCount > 0 ? AppColors.noConformeBg : AppColors.conformeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$_conformeCount Conformes | $_failedCount Fallas',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _failedCount > 0 ? AppColors.noConforme : AppColors.conforme,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              children: [
                // Concrete & Pour Metadata Card
                _buildMetadataCard(),
                const SizedBox(height: 16),

                // Checklist Items by Section
                ...sections.entries.map((sec) => _buildSectionBlock(sec.key, sec.value)),

                // General Observations Card
                _buildGeneralObservationsCard(),
                const SizedBox(height: 16),

                // Digital Signatures Card
                _buildSignaturesCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveInspection(finalize: true),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: Text(
                  _failedCount > 0
                      ? 'FINALIZAR Y CREAR $_failedCount HALLAZGO(S)'
                      : 'FINALIZAR Y LIBERAR CONFORMIDAD',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _failedCount > 0 ? AppColors.noConforme : AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DATOS DEL VACIADO / LIBERACIÓN',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pourDateController,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Vaciado',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _batchNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Guía Mixer / Lote',
                      labelStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _weatherController,
              decoration: const InputDecoration(
                labelText: 'Condición Climática (Temp / Humedad)',
                labelStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBlock(String sectionTitle, List<TemplateItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.textMain,
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          ),
          child: Text(
            sectionTitle.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _buildItemCard(item)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildItemCard(TemplateItem item) {
    final answer = _answers[item.id] ?? InspectionAnswer(id: '', inspectionId: _inspectionId, itemId: item.id);
    final isFailed = answer.status == 'no_conforme';
    final isConforme = answer.status == 'conforme';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: isFailed ? AppColors.noConformeBg.withValues(alpha: 0.3) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        side: BorderSide(
          color: isFailed ? AppColors.noConforme : (isConforme ? AppColors.conforme.withValues(alpha: 0.3) : AppColors.border),
          width: isFailed ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code & Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    item.code,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.questionText,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                ),
                if (item.isCritical)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.noConforme,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('CRÍTICO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),

            if (item.toleranceMin != null && item.toleranceMax != null) ...[
              const SizedBox(height: 6),
              Text(
                'Tolerancia Norma: ${item.toleranceMin} - ${item.toleranceMax} ${item.unit ?? ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],

            const SizedBox(height: 12),

            // Segmented Evaluation Buttons (>= 48px height)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppDimensions.minTouchTarget,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          answer.status = 'conforme';
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: answer.status == 'conforme' ? AppColors.conforme : Colors.white,
                        foregroundColor: answer.status == 'conforme' ? Colors.white : AppColors.conforme,
                        side: const BorderSide(color: AppColors.conforme, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
                      ),
                      child: const Text('CONFORME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: AppDimensions.minTouchTarget,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          answer.status = 'no_conforme';
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: answer.status == 'no_conforme' ? AppColors.noConforme : Colors.white,
                        foregroundColor: answer.status == 'no_conforme' ? Colors.white : AppColors.noConforme,
                        side: const BorderSide(color: AppColors.noConforme, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
                      ),
                      child: const Text('NO CONFORME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  height: AppDimensions.minTouchTarget,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        answer.status = 'no_aplica';
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: answer.status == 'no_aplica' ? AppColors.textMuted : Colors.white,
                      foregroundColor: answer.status == 'no_aplica' ? Colors.white : AppColors.textMuted,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
                    ),
                    child: const Text('N/A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

            // If numeric tolerance, show input field
            if (item.itemType == 'numeric_tolerance') ...[
              const SizedBox(height: 10),
              TextFormField(
                initialValue: answer.numericValue?.toString() ?? '',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Valor Medido (${item.unit ?? ''})',
                  labelStyle: const TextStyle(fontSize: 12),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  suffixText: item.unit,
                ),
                onChanged: (val) {
                  final numVal = double.tryParse(val);
                  answer.numericValue = numVal;
                  if (numVal != null && item.toleranceMin != null && item.toleranceMax != null) {
                    if (numVal < item.toleranceMin! || numVal > item.toleranceMax!) {
                      answer.status = 'no_conforme';
                    } else {
                      answer.status = 'conforme';
                    }
                    setState(() {});
                  }
                },
              ),
            ],

            // Observation / Defect note if failed
            if (isFailed) ...[
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Descripción del defecto / Hallazgo',
                  hintText: 'Detalle qué no cumple para el contratista...',
                  labelStyle: TextStyle(fontSize: 12, color: AppColors.noConforme),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (val) => answer.observationText = val,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralObservationsCard() {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OBSERVACIONES GENERALES / CUADERNO DE OBRA',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _generalNotesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Anotaciones adicionales para el acta oficial...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignaturesCard() {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FIRMAS DE CONFORMIDAD Y LIBERACIÓN',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _isSignedByInspector,
              activeColor: AppColors.conforme,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Firma Calidad: ${widget.currentUser.fullName}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Constancia de inspección técnica en sitio', style: TextStyle(fontSize: 11)),
              onChanged: (val) => setState(() => _isSignedByInspector = val ?? true),
            ),
            CheckboxListTile(
              value: _isSignedByResident,
              activeColor: AppColors.conforme,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Firma Residencia: ${widget.project.residentName ?? "Ing. Residente CIP"}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Autorización de pase a siguiente partida', style: TextStyle(fontSize: 11)),
              onChanged: (val) => setState(() => _isSignedByResident = val ?? false),
            ),
          ],
        ),
      ),
    );
  }
}
