import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../data/local_db.dart';
import '../../data/api_client.dart';
import '../../data/sync_manager.dart';
import '../widgets/offline_banner.dart';
import '../widgets/status_badge.dart';
import 'location_selector_screen.dart';
import 'template_selector_screen.dart';
import 'inspection_form_screen.dart';
import 'findings_list_screen.dart';
import 'pdf_preview_screen.dart';
import 'login_screen.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  final User currentUser;

  const HomeScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  Project? _selectedProject;
  List<Project> _projects = [];
  List<Inspection> _inspections = [];
  List<Finding> _findings = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load Projects
      List<Project> projects = await LocalDatabase.instance.getProjects();
      if (projects.isEmpty) {
        final res = await ApiClient.instance.get('/projects');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List<dynamic>;
          projects = data.map((json) => Project.fromJson(json)).toList();
          await LocalDatabase.instance.saveProjects(projects);
        }
      }

      if (projects.isEmpty) {
        projects = [
          Project(
            id: 'proj-las-palmeras',
            code: 'OBRA-2026-MIR',
            name: 'Edificio Residencial Las Palmeras',
            address: 'Av. Coronel Portillo 450, Miraflores',
            district: 'Miraflores, Lima',
            residentName: 'Ing. Carlos Mendoza (CIP 84920)',
            itoName: 'Ing. Patricia Thorne (CIP 63102)',
          ),
        ];
        await LocalDatabase.instance.saveProjects(projects);
      }

      _projects = projects;
      _selectedProject = projects.first;

      // 2. Load Inspections for selected project
      List<Inspection> inspections = await LocalDatabase.instance.getInspections(_selectedProject!.id);
      if (inspections.isEmpty) {
        final res = await ApiClient.instance.get('/inspections?project_id=${_selectedProject!.id}');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List<dynamic>;
          inspections = data.map((json) => Inspection.fromJson(json)).toList();
        }
      }

      // 3. Load Findings
      final isContractor = widget.currentUser.role == 'contratista';
      List<Finding> findings = await LocalDatabase.instance.getFindings(
        projectId: _selectedProject!.id,
        contractorId: isContractor ? widget.currentUser.id : null,
      );

      setState(() {
        _inspections = inspections;
        _findings = findings;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startNewInspection() async {
    if (_selectedProject == null) return;

    // 1. Pick Location
    final locationResult = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSelectorScreen(
          projectId: _selectedProject!.id,
          projectName: _selectedProject!.name,
        ),
      ),
    );

    if (locationResult == null) return;

    // 2. Pick Template
    if (!mounted) return;
    final templateResult = await Navigator.push<InspectionTemplate>(
      context,
      MaterialPageRoute(builder: (_) => const TemplateSelectorScreen()),
    );

    if (templateResult == null) return;

    // 3. Open Inspection Form
    if (!mounted) return;
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionFormScreen(
          project: _selectedProject!,
          locationId: locationResult['locationId'],
          locationName: locationResult['locationName'],
          locationPath: locationResult['locationPath'],
          template: templateResult,
          currentUser: widget.currentUser,
        ),
      ),
    );

    if (created == true) {
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final conformeCount = _inspections.where((i) => i.status == 'conforme').length;
    final openFindingsCount = _findings.where((f) => f.status == 'abierto' || f.status == 'en_proceso').length;
    final overdueCount = _findings.where((f) => f.isOverdue || (f.status == 'abierto' && f.dueDate.contains('14'))).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                if (_projects.length > 1) {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => ListView(
                      shrinkWrap: true,
                      children: _projects.map((p) => ListTile(
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(p.code),
                        selected: p.id == _selectedProject?.id,
                        onTap: () {
                          setState(() => _selectedProject = p);
                          Navigator.pop(ctx);
                          _loadDashboardData();
                        },
                      )).toList(),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  Text(
                    _selectedProject?.name ?? 'Protokol QC',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_drop_down, color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
          Text(
            '${widget.currentUser.fullName} • ${_roleTitle(widget.currentUser.role)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.sync_rounded, color: AppColors.textMuted),
          tooltip: 'Sincronizar ahora',
          onPressed: () async {
            await SyncManager.instance.syncNow();
            if (mounted) _loadDashboardData();
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
          tooltip: 'Cerrar sesión',
          onPressed: () async {
            await ApiClient.instance.setToken(null);
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ],
    ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                const OfflineBanner(),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadDashboardData,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      children: [
                        // Morning KPI Cards Grid
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                title: 'LIBERACIONES',
                                value: '$conformeCount',
                                subtitle: 'Conformes',
                                color: AppColors.conforme,
                                icon: Icons.verified_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'HALLAZGOS',
                                value: '$openFindingsCount',
                                subtitle: 'Abiertos en obra',
                                color: openFindingsCount > 0 ? AppColors.warning : AppColors.conforme,
                                icon: Icons.warning_amber_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'CRÍTICOS',
                                value: '$overdueCount',
                                subtitle: 'Vencidos / Urgentes',
                                color: overdueCount > 0 ? AppColors.noConforme : AppColors.textMuted,
                                icon: Icons.error_outline_rounded,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons (Minimum 48px touch targets)
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: AppDimensions.buttonHeight,
                                child: ElevatedButton.icon(
                                  onPressed: _startNewInspection,
                                  icon: const Icon(Icons.add_task_rounded, color: Colors.white),
                                  label: const Text(
                                    '+ NUEVA INSPECCIÓN',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: AppDimensions.buttonHeight,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FindingsListScreen(
                                          project: _selectedProject!,
                                          currentUser: widget.currentUser,
                                        ),
                                      ),
                                    ).then((_) => _loadDashboardData());
                                  },
                                  icon: const Icon(Icons.assignment_late_outlined, size: 18),
                                  label: Text(
                                    'HALLAZGOS ($openFindingsCount)',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textMain,
                                    side: const BorderSide(color: AppColors.border, width: 1.5),
                                    backgroundColor: AppColors.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Section Header: Protocolos Recientes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'PROTOCOLOS Y LIBERACIONES RECIENTES',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              '${_inspections.length} total',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Inspections List
                        if (_inspections.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: const [
                                Icon(Icons.assignment_outlined, size: 40, color: AppColors.textSecondary),
                                SizedBox(height: 10),
                                Text(
                                  'No hay protocolos registrados aún en esta obra.',
                                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Presione "+ Nueva Inspección" para liberar una partida.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._inspections.map((insp) => _buildInspectionCard(insp)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionCard(Inspection insp) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        onTap: () {
          // Open PDF Preview for completed inspection
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfPreviewScreen(
                inspection: insp,
                project: _selectedProject!,
                locationPath: insp.locationName ?? 'Sector de Obra',
                template: InspectionTemplate(
                  id: insp.templateId,
                  family: 'concreto',
                  code: 'PROT-E060',
                  title: insp.templateTitle ?? 'Protocolo de Vaciado',
                  items: [],
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      insp.code,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                  ),
                  StatusBadge(status: insp.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                insp.templateTitle ?? 'Protocolo Técnico',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      insp.locationName ?? 'Ubicación General',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vaciado: ${insp.pourDate ?? "N/A"}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Ver PDF',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleTitle(String role) {
    switch (role) {
      case 'calidad':
        return 'Especialista de Calidad';
      case 'residente':
        return 'Residente de Obra';
      case 'contratista':
        return 'Contratista';
      case 'cliente_ito':
        return 'Supervisor ITO';
      case 'admin':
        return 'Administrador';
      default:
        return role;
    }
  }
}
