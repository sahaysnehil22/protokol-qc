import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../data/local_db.dart';
import '../../data/api_client.dart';
import '../../services/share_service.dart';
import '../widgets/status_badge.dart';
import '../widgets/offline_banner.dart';
import 'finding_detail_screen.dart';
import 'dart:convert';

class FindingsListScreen extends StatefulWidget {
  final Project project;
  final User currentUser;

  const FindingsListScreen({
    super.key,
    required this.project,
    required this.currentUser,
  });

  @override
  State<FindingsListScreen> createState() => _FindingsListScreenState();
}

class _FindingsListScreenState extends State<FindingsListScreen> {
  bool _isLoading = true;
  List<Finding> _findings = [];
  String _activeFilter = 'todos'; // todos, abiertos, vencidos, subsanados, verificados

  @override
  void initState() {
    super.initState();
    _loadFindings();
  }

  Future<void> _loadFindings() async {
    setState(() => _isLoading = true);
    try {
      final isContractor = widget.currentUser.role == 'contratista';

      // Load from local DB first
      List<Finding> list = await LocalDatabase.instance.getFindings(
        projectId: widget.project.id,
        contractorId: isContractor ? widget.currentUser.id : null,
      );

      // If empty, fetch from API
      if (list.isEmpty) {
        final res = await ApiClient.instance.get('/findings?project_id=${widget.project.id}');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List<dynamic>;
          list = data.map((json) => Finding.fromJson(json)).toList();
          await LocalDatabase.instance.saveFindings(list);
        }
      }

      // If still empty (offline initial run), fallback seed findings
      if (list.isEmpty) {
        list = [
          Finding(
            id: 'hal-001',
            projectId: widget.project.id,
            locationId: 'loc-piso-2',
            code: 'HAL-2026-0014',
            title: 'Recubrimiento insuficiente en armadura de placa',
            description: 'Recubrimiento medido 1.2 cm en borde libre, especificado 2.5 cm según plano E-04.',
            severity: 'critico',
            status: 'abierto',
            assignedTrade: 'Fierrería',
            dueDate: '16/10/2026',
            projectName: widget.project.name,
            locationName: 'Piso 2 - Placa PL-01 Eje 3-B',
            isOverdue: false,
          ),
          Finding(
            id: 'hal-002',
            projectId: widget.project.id,
            locationId: 'loc-piso-2',
            code: 'HAL-2026-0015',
            title: 'Fisura capilar en losa aligerada',
            description: 'Fisura superficial por retracción plástica en paño central.',
            severity: 'moderado',
            status: 'cerrado_con_evidencia',
            assignedTrade: 'Estructuras Concreto',
            dueDate: '14/10/2026',
            projectName: widget.project.name,
            locationName: 'Piso 2 - Losa Sector 1',
            isOverdue: true,
          ),
          Finding(
            id: 'hal-003',
            projectId: widget.project.id,
            locationId: 'loc-dpto-201',
            code: 'HAL-2026-0018',
            title: 'Descuadre en vano de puerta principal',
            description: 'Diferencia de 8mm en diagonal de vano de ingreso.',
            severity: 'leve',
            status: 'verificado',
            assignedTrade: 'Pintura y Acabados',
            dueDate: '12/10/2026',
            projectName: widget.project.name,
            locationName: 'Dpto 201 - Ingreso',
            isOverdue: false,
          ),
        ];
        await LocalDatabase.instance.saveFindings(list);
      }

      setState(() {
        _findings = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<Finding> get _filteredFindings {
    switch (_activeFilter) {
      case 'abiertos':
        return _findings.where((f) => f.status == 'abierto' || f.status == 'en_proceso').toList();
      case 'vencidos':
        return _findings.where((f) => f.isOverdue || (f.status == 'abierto' && f.dueDate.contains('14'))).toList();
      case 'subsanados':
        return _findings.where((f) => f.status == 'cerrado_con_evidencia').toList();
      case 'verificados':
        return _findings.where((f) => f.status == 'verificado').toList();
      case 'todos':
      default:
        return _findings;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hallazgos y Observaciones',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
            ),
            Text(
              '${widget.project.name} • ${_findings.length} registrados',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),

          // Filter Chips Strip
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('todos', 'Todos (${_findings.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('abiertos', 'Abiertos'),
                  const SizedBox(width: 8),
                  _buildFilterChip('vencidos', 'Por Vencer / Vencidos'),
                  const SizedBox(width: 8),
                  _buildFilterChip('subsanados', 'Subsanados'),
                  const SizedBox(width: 8),
                  _buildFilterChip('verificados', 'Verificados'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredFindings.isEmpty
                    ? const Center(
                        child: Text('No hay hallazgos con el filtro seleccionado.', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        itemCount: _filteredFindings.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final f = _filteredFindings[index];
                          return Card(
                            elevation: 0,
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                              side: BorderSide(
                                color: f.severity == 'critico' && f.status == 'abierto'
                                    ? AppColors.noConforme.withValues(alpha: 0.5)
                                    : AppColors.border,
                                width: f.severity == 'critico' && f.status == 'abierto' ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FindingDetailScreen(
                                      finding: f,
                                      currentUser: widget.currentUser,
                                    ),
                                  ),
                                );
                                _loadFindings();
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
                                            f.code,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                          ),
                                        ),
                                        StatusBadge(status: f.status, isFinding: true),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      f.title,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      f.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.3),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            f.locationName ?? 'Ubicación en obra',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.share_outlined, size: 18, color: AppColors.primary),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'WhatsApp',
                                          onPressed: () => ShareService.shareFindingViaWhatsApp(f),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Especialidad: ${f.assignedTrade}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMain),
                                        ),
                                        Text(
                                          'Vence: ${f.dueDate}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: f.status == 'abierto' ? AppColors.noConforme : AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.textMain,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textMain,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(color: isSelected ? AppColors.textMain : AppColors.border),
      onSelected: (_) {
        setState(() => _activeFilter = key);
      },
    );
  }
}
