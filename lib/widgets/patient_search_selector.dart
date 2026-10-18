import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';

class PatientSearchSelector extends StatelessWidget {
  final Paciente? selectedPatient;
  final List<Paciente> patients;
  final ValueChanged<Paciente> onPatientSelected;
  final String label;
  final String hint;

  const PatientSearchSelector({
    super.key,
    required this.selectedPatient,
    required this.patients,
    required this.onPatientSelected,
    this.label = 'Paciente Seleccionado:',
    this.hint = 'Toca aquí para buscar paciente con lupa 🔍',
  });

  void _abrirBuscadorPacientes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PatientSearchModal(
        patients: patients,
        selectedPatient: selectedPatient,
        onSelected: (p) {
          Navigator.pop(ctx);
          onPatientSelected(p);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPatient = selectedPatient != null;

    return InkWell(
      onTap: () => _abrirBuscadorPacientes(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasPatient ? AppColors.primary.withOpacity(0.4) : AppColors.ghostOutline,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasPatient ? AppColors.primary.withOpacity(0.12) : AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasPatient ? Icons.person : Icons.search,
                color: hasPatient ? AppColors.primary : AppColors.textLight,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPatient
                        ? '${selectedPatient!.nombre} ${selectedPatient!.apellido}'
                        : hint,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: hasPatient ? FontWeight.bold : FontWeight.w500,
                      color: hasPatient ? AppColors.onSurface : AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasPatient && selectedPatient!.telefono.isNotEmpty)
                    Text(
                      'Tel: ${selectedPatient!.telefono}',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Buscar',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientSearchModal extends StatefulWidget {
  final List<Paciente> patients;
  final Paciente? selectedPatient;
  final ValueChanged<Paciente> onSelected;

  const _PatientSearchModal({
    required this.patients,
    required this.selectedPatient,
    required this.onSelected,
  });

  @override
  State<_PatientSearchModal> createState() => _PatientSearchModalState();
}

class _PatientSearchModalState extends State<_PatientSearchModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Paciente> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.patients;
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.patients;
      } else {
        _filtered = widget.patients.where((p) {
          final nombre = '${p.nombre} ${p.apellido}'.toLowerCase();
          final tel = p.telefono.replaceAll(RegExp(r'[^\d]'), '');
          final email = p.email.toLowerCase();
          return nombre.contains(q) || tel.contains(q) || email.contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ghostOutline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.search, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Buscar Paciente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textLight),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Field with Lupa
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, apellido o teléfono...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppColors.textLight),
                      onPressed: () {
                        _searchCtrl.clear();
                        _filter('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Results count
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_filtered.length} paciente(s) encontrado(s)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_outlined, size: 54, color: AppColors.textLight.withOpacity(0.5)),
                        const SizedBox(height: 10),
                        const Text(
                          'No se encontraron pacientes con esa búsqueda',
                          style: TextStyle(fontSize: 13, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final p = _filtered[index];
                      final bool isSelected = widget.selectedPatient?.id == p.id;
                      final initial = (p.nombre.isNotEmpty ? p.nombre[0] : 'P').toUpperCase();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withOpacity(0.08) : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.ghostOutline,
                            width: isSelected ? 1.5 : 0.8,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => widget.onSelected(p),
                          leading: CircleAvatar(
                            backgroundColor: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
                            foregroundColor: isSelected ? Colors.white : AppColors.primary,
                            child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          title: Text(
                            '${p.nombre} ${p.apellido}',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Tel: ${p.telefono.isEmpty ? "Sin teléfono" : p.telefono}${p.email.isNotEmpty ? " • ${p.email}" : ""}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: AppColors.primary)
                              : const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
