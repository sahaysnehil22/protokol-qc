import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../data/local_db.dart';
import '../../data/api_client.dart';
import 'dart:convert';

class TemplateSelectorScreen extends StatefulWidget {
  const TemplateSelectorScreen({super.key});

  @override
  State<TemplateSelectorScreen> createState() => _TemplateSelectorScreenState();
}

class _TemplateSelectorScreenState extends State<TemplateSelectorScreen> {
  bool _isLoading = true;
  List<InspectionTemplate> _templates = [];
  String _selectedFamily = 'todos';

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);

    try {
      List<InspectionTemplate> list = await LocalDatabase.instance.getTemplates();

      if (list.isEmpty) {
        final res = await ApiClient.instance.get('/templates');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as List<dynamic>;
          list = data.map((json) => InspectionTemplate.fromJson(json)).toList();
          await LocalDatabase.instance.saveTemplates(list);
        }
      }

      setState(() {
        _templates = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<InspectionTemplate> get _filteredTemplates {
    if (_selectedFamily == 'todos') return _templates;
    return _templates.where((t) => t.family.toLowerCase() == _selectedFamily).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          'Plantillas de Protocolo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter Family Chips
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('todos', 'Todas'),
                        const SizedBox(width: 8),
                        _buildFilterChip('concreto', 'Concreto'),
                        const SizedBox(width: 8),
                        _buildFilterChip('acero', 'Acero'),
                        const SizedBox(width: 8),
                        _buildFilterChip('encofrado', 'Encofrado'),
                        const SizedBox(width: 8),
                        _buildFilterChip('topografia', 'Topografía'),
                        const SizedBox(width: 8),
                        _buildFilterChip('acabados', 'Acabados / Repasos'),
                        const SizedBox(width: 8),
                        _buildFilterChip('recepcion', 'Acta Recepción'),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),

                Expanded(
                  child: _filteredTemplates.isEmpty
                      ? const Center(
                          child: Text('No hay plantillas en esta categoría.', style: TextStyle(color: AppColors.textSecondary)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          itemCount: _filteredTemplates.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final tmpl = _filteredTemplates[index];
                            return Card(
                              elevation: 0,
                              color: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                                onTap: () => Navigator.pop(context, tmpl),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tmpl.code,
                                              style: const TextStyle(
                                                color: AppColors.primaryDark,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${tmpl.items.length} ítems de control',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        tmpl.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textMain,
                                        ),
                                      ),
                                      if (tmpl.description != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          tmpl.description!,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Seleccionar para inspección',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
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
    final isSelected = _selectedFamily == key;
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
        setState(() {
          _selectedFamily = key;
        });
      },
    );
  }
}
