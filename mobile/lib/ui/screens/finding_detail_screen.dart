import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../data/local_db.dart';
import '../../data/sync_manager.dart';
import '../../services/share_service.dart';
import '../widgets/status_badge.dart';

class FindingDetailScreen extends StatefulWidget {
  final Finding finding;
  final User currentUser;

  const FindingDetailScreen({
    super.key,
    required this.finding,
    required this.currentUser,
  });

  @override
  State<FindingDetailScreen> createState() => _FindingDetailScreenState();
}

class _FindingDetailScreenState extends State<FindingDetailScreen> {
  late Finding _finding;
  final _resolutionNotesController = TextEditingController();
  String? _simulatedResolutionPhoto;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _finding = widget.finding;
    _resolutionNotesController.text = _finding.resolutionNotes ?? '';
    _simulatedResolutionPhoto = _finding.resolutionPhotoUrl;
  }

  bool get _canVerify => widget.currentUser.role == 'calidad' || widget.currentUser.role == 'residente' || widget.currentUser.role == 'admin';

  Future<void> _submitResolution() async {
    if (_resolutionNotesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe ingresar las notas de la corrección realizada.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedFinding = Finding(
        id: _finding.id,
        projectId: _finding.projectId,
        inspectionId: _finding.inspectionId,
        locationId: _finding.locationId,
        code: _finding.code,
        title: _finding.title,
        description: _finding.description,
        severity: _finding.severity,
        status: 'cerrado_con_evidencia',
        assignedContractorId: _finding.assignedContractorId,
        assignedTrade: _finding.assignedTrade,
        dueDate: _finding.dueDate,
        initialPhotoUrl: _finding.initialPhotoUrl,
        resolutionPhotoUrl: _simulatedResolutionPhoto ?? 'https://storage.protokol.pe/evidence/res-${_finding.code}.jpg',
        resolutionNotes: _resolutionNotesController.text.trim(),
        resolvedAt: DateTime.now().toIso8601String(),
        projectName: _finding.projectName,
        locationName: _finding.locationName,
        contractorName: _finding.contractorName,
      );

      // Save locally
      await LocalDatabase.instance.updateFinding(updatedFinding);

      // Queue offline sync
      await LocalDatabase.instance.queueOperation(
        entityType: 'finding',
        entityId: updatedFinding.id,
        operation: 'UPDATE_STATUS',
        payload: {
          'status': 'cerrado_con_evidencia',
          'resolution_photo_url': updatedFinding.resolutionPhotoUrl,
          'resolution_notes': updatedFinding.resolutionNotes,
          'resolved_at': updatedFinding.resolvedAt,
        },
      );

      SyncManager.instance.syncNow();

      setState(() => _finding = updatedFinding);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidencia cargada con éxito. Pendiente de verificación por Calidad.'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.noConforme),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _verifyFinding(bool approved) async {
    setState(() => _isSaving = true);
    try {
      final newStatus = approved ? 'verificado' : 'abierto';
      final updatedFinding = Finding(
        id: _finding.id,
        projectId: _finding.projectId,
        inspectionId: _finding.inspectionId,
        locationId: _finding.locationId,
        code: _finding.code,
        title: _finding.title,
        description: _finding.description,
        severity: _finding.severity,
        status: newStatus,
        assignedContractorId: _finding.assignedContractorId,
        assignedTrade: _finding.assignedTrade,
        dueDate: _finding.dueDate,
        initialPhotoUrl: _finding.initialPhotoUrl,
        resolutionPhotoUrl: _finding.resolutionPhotoUrl,
        resolutionNotes: _finding.resolutionNotes,
        resolvedAt: _finding.resolvedAt,
        verifiedAt: approved ? DateTime.now().toIso8601String() : null,
        projectName: _finding.projectName,
        locationName: _finding.locationName,
        contractorName: _finding.contractorName,
      );

      await LocalDatabase.instance.updateFinding(updatedFinding);

      await LocalDatabase.instance.queueOperation(
        entityType: 'finding',
        entityId: updatedFinding.id,
        operation: 'UPDATE_STATUS',
        payload: {
          'status': newStatus,
          'verified_at': updatedFinding.verifiedAt,
        },
      );

      SyncManager.instance.syncNow();
      setState(() => _finding = updatedFinding);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? 'Hallazgo verificado y cerrado conforme.' : 'Subsanación rechazada.'),
            backgroundColor: approved ? AppColors.conforme : AppColors.noConforme,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.noConforme),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: Text(
          _finding.code,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.primary),
            tooltip: 'Compartir Hallazgo por WhatsApp',
            onPressed: () => ShareService.shareFindingViaWhatsApp(_finding),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          // Header Card
          Card(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StatusBadge(status: _finding.status, isFinding: true),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _finding.severity == 'critico' ? AppColors.noConformeBg : AppColors.warningBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _finding.severity.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _finding.severity == 'critico' ? AppColors.noConforme : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _finding.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _finding.description,
                    style: const TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.4),
                  ),
                  const Divider(height: 24, color: AppColors.border),

                  // Metadata Key-Values
                  _buildMetaRow('Proyecto', _finding.projectName ?? 'Edificio Las Palmeras'),
                  const SizedBox(height: 6),
                  _buildMetaRow('Ubicación en Obra', _finding.locationName ?? 'Sector Estructural'),
                  const SizedBox(height: 6),
                  _buildMetaRow('Especialidad Responsable', _finding.assignedTrade),
                  const SizedBox(height: 6),
                  _buildMetaRow(
                    'Fecha Límite Subsanación',
                    _finding.dueDate,
                    isWarning: _finding.isOverdue || _finding.status == 'abierto',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Initial Evidence Box
          Card(
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
                    '1. EVIDENCIA INICIAL DEL DEFECTO',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt_outlined, size: 36, color: AppColors.textSecondary),
                          SizedBox(height: 6),
                          Text('Foto de Registro de Campo (Inspección)', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Resolution Evidence Box (Contractor Subsanación)
          Card(
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
                    '2. EVIDENCIA DE SUBSANACIÓN Y REPARACIÓN',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),

                  // Simulated Photo Capture Box
                  InkWell(
                    onTap: (_finding.status == 'abierto' || _finding.status == 'en_proceso')
                        ? () {
                            setState(() {
                              _simulatedResolutionPhoto = 'https://storage.protokol.pe/evidence/res-${_finding.code}.jpg';
                            });
                          }
                        : null,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _simulatedResolutionPhoto != null ? AppColors.conformeBg.withValues(alpha: 0.3) : AppColors.background,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                        border: Border.all(
                          color: _simulatedResolutionPhoto != null ? AppColors.conforme : AppColors.border,
                          width: _simulatedResolutionPhoto != null ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _simulatedResolutionPhoto != null ? Icons.check_circle : Icons.add_a_photo_outlined,
                              size: 36,
                              color: _simulatedResolutionPhoto != null ? AppColors.conforme : AppColors.primary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _simulatedResolutionPhoto != null
                                  ? 'Fotografía de Subsanación Adjunta ✓'
                                  : 'Tocar para Capturar Foto de Evidencia',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _simulatedResolutionPhoto != null ? AppColors.conforme : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: _resolutionNotesController,
                    enabled: _finding.status == 'abierto' || _finding.status == 'en_proceso',
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del trabajo correctivo ejecutado',
                      hintText: 'ej. Se colocó refuerzo adicional de estribos y se resanó el recubrimiento...',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (_finding.status == 'abierto' || _finding.status == 'en_proceso') ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submitResolution,
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                        label: const Text(
                          'ENVIAR EVIDENCIA DE SUBSANACIÓN',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Quality Verification Actions
          if (_canVerify && _finding.status == 'cerrado_con_evidencia') ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '3. DICTAMEN DE CALIDAD / RESIDENCIA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'El contratista ha presentado la evidencia técnica. Evalúe la conformidad del trabajo.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: AppDimensions.buttonHeight,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : () => _verifyFinding(true),
                              icon: const Icon(Icons.verified_outlined, color: Colors.white),
                              label: const Text('APROBAR Y CERRAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.conforme,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: AppDimensions.buttonHeight,
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : () => _verifyFinding(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.noConforme,
                              side: const BorderSide(color: AppColors.noConforme),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
                            ),
                            child: const Text('RECHAZAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isWarning = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isWarning ? AppColors.noConforme : AppColors.textMain,
          ),
        ),
      ],
    );
  }
}
