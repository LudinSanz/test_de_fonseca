import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';
import '../services/supabase_service.dart';

class TreatmentsScreen extends StatefulWidget {
  final Paciente? paciente;

  const TreatmentsScreen({super.key, this.paciente});

  @override
  State<TreatmentsScreen> createState() => _TreatmentsScreenState();
}

class _TreatmentsScreenState extends State<TreatmentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Paciente> _pacientes = [];
  Paciente? _pacienteSeleccionado;

  // Selected Tooth State for Interactive Odontogram
  int _selectedToothNumber = 16;
  final Map<int, Map<String, dynamic>> _odontogramState = {};
  final List<Map<String, dynamic>> _tratamientosGenerales = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarPacientes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  
  Future<void> _cargarTratamientosDelPaciente(String pacienteId) async {
    setState(() {
      _isLoading = true;
      _odontogramState.clear();
      _tratamientosGenerales.clear();
    });
    try {
      final supabaseService = SupabaseService();
      final tratamientos = await supabaseService.obtenerTratamientos(pacienteId: pacienteId);
      for (var t in tratamientos) {
        int d = t["diente"] ?? 0;
        if (d > 0) {
          _odontogramState[d] = {
            "id": t["id"],
            "diagnostico": t["diagnostico"],
            "tratamiento": t["tratamiento"],
            "evolucion": t["evolucion"],
            "precio_gtq": t["precio_gtq"],
            "estado": t["estado"],
            "notas": t["notas"],
          };
        } else {
          _tratamientosGenerales.add(Map<String, dynamic>.from(t));
        }
      }
    } catch (e) {
      debugPrint("Error loading tratamientos: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarPacientes() async {
    setState(() => _isLoading = true);
    try {
      final supabaseService = SupabaseService();
      final list = await supabaseService.obtenerPacientes();
      setState(() {
        _pacientes = list;
        if (widget.paciente != null) {
          _pacienteSeleccionado = list.firstWhere(
            (p) => p.id == widget.paciente!.id,
            orElse: () => widget.paciente!,
          );
        } else if (list.isNotEmpty) {
          _pacienteSeleccionado = list.first;
        }
      });
    } catch (e) {
      debugPrint('Error al cargar pacientes en Tratamientos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _mostrarDialogoEdicionPieza(int toothNum) {
    final info = _odontogramState[toothNum] ?? {};
    final diagCtrl = TextEditingController(text: info["diagnostico"] ?? "");
    final precioCtrl = TextEditingController(text: info["precio_gtq"]?.toString() ?? "");
    final notasCtrl = TextEditingController(text: info["notas"] ?? "");

    String trat = info["tratamiento"] ?? "Ninguno";
    if (trat.isEmpty || trat == "Sin tratamiento") trat = "Ninguno";

    String evol = info["evolucion"] ?? "Evaluación";
    if (evol.isEmpty) evol = "Evaluación";

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Editar Pieza #$toothNum", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (ctx, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: trat,
                      decoration: const InputDecoration(labelText: "Tratamiento a realizar"),
                      items: [
                        "Limpieza Dental", "Extracción", "Endodoncia", "Corona", 
                        "Resina", "Blanqueamiento", "Ortodoncia", "Implante", "Ninguno"
                      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => trat = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: evol,
                      decoration: const InputDecoration(labelText: "Etapa / Evolución"),
                      items: [
                        "Evaluación", "Presupuesto", "En Proceso", "Terminado", "Cancelado"
                      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => evol = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: diagCtrl, decoration: const InputDecoration(labelText: "Diagnóstico")),
                    const SizedBox(height: 10),
                    TextField(controller: precioCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Precio (GTQ)")),
                    const SizedBox(height: 10),
                    TextField(controller: notasCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Notas Clínicas")),
                  ],
                );
              }
            )
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final preciogtq = double.tryParse(precioCtrl.text) ?? 0.0;
                String estadoStr = "Pendiente";
                if (evol == "Terminado") estadoStr = "Tratado";
                if (evol == "Cancelado") estadoStr = "Sano";
                if (evol == "Evaluación" && trat == "Ninguno") estadoStr = "Sano";
                if (evol == "En Proceso") estadoStr = "Problema";

                final tratMap = {
                  "id": _odontogramState[toothNum]?["id"] ?? "",
                  "paciente_id": _pacienteSeleccionado?.id ?? "",
                  "diente": toothNum,
                  "diagnostico": diagCtrl.text,
                  "tratamiento": trat,
                  "evolucion": evol,
                  "precio_gtq": preciogtq,
                  "estado": estadoStr,
                  "notas": notasCtrl.text,
                  "fecha": DateTime.now().toIso8601String(),
                };

                setState(() {
                  _odontogramState[toothNum] = tratMap;
                });

                if (_pacienteSeleccionado != null) {
                  final supabaseService = SupabaseService();
                  await supabaseService.guardarTratamiento(tratMap);
                }

                if (mounted) Navigator.pop(ctx);
              },
              child: const Text("Guardar"),
            ),
          ],
        );
      },
    );
  }

  double _calcularTotal() {
    double total = 0;
    _odontogramState.forEach((key, value) {
      if (value["precio_gtq"] != null) {
        total += (value["precio_gtq"] as num).toDouble();
      }
    });
    for (var value in _tratamientosGenerales) {
      if (value["precio_gtq"] != null) {
        total += (value["precio_gtq"] as num).toDouble();
      }
    }
    return total;
  }

  Color _getToothColor(int toothNum) {
    final info = _odontogramState[toothNum];
    if (info == null) return AppColors.surfaceContainerLow;
    final estado = info['estado'] ?? 'Sano';
    if (estado == 'Sano') return AppColors.surfaceContainerLow;
    if (estado == 'Pendiente') return AppColors.warning;
    if (estado == 'Problema') return AppColors.error;
    if (estado == 'Tratado') return AppColors.success;
    return AppColors.surfaceContainerLow;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/rizo_logo.png',
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.medical_services_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIZO DENTAL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Tratamientos • Odontograma • Estética Facial',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  // Patient Selector Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: AppColors.shadowSoft, blurRadius: 18, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paciente Seleccionado:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textLight),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.ghostOutline, width: 1.0),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Paciente>(
                              value: _pacienteSeleccionado,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                              items: _pacientes.map((p) {
                                return DropdownMenuItem<Paciente>(
                                  value: p,
                                  child: Text(
                                    '${p.nombre} ${p.apellido} • Tel: ${p.telefono}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (p) {
                                if (p != null) {
                                  setState(() => _pacienteSeleccionado = p);
                                  _cargarTratamientosDelPaciente(p.id);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Navigation Tabs
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textLight,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      tabs: const [
                        Tab(text: 'Odontograma'),
                        Tab(text: 'Plan de Tratamiento'),
                        Tab(text: 'Bichectomía & Estética'),
                      ],
                    ),
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOdontogramaTab(),
                        _buildPlanTratamientoTab(),
                        _buildEsteticaFacialTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // TAB 1: ODONTOGRAMA INTERACTIVO (Piezas 11 a 48)
  Widget _buildOdontogramaTab() {
    final infoTooth = _odontogramState[_selectedToothNumber];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leyenda de Colores del Odontograma
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Tratado', AppColors.success),
                _buildLegendItem('Pendiente', AppColors.warning),
                _buildLegendItem('Problema', AppColors.error),
                _buildLegendItem('Sano', AppColors.surfaceContainerLow),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Cuadrantes Superiores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Arcada Superior (Cuadrantes 1 y 2)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int t = 18; t >= 11; t--) _buildToothItem(t),
                      Container(width: 2, height: 40, color: AppColors.primary, margin: const EdgeInsets.symmetric(horizontal: 8)),
                      for (int t = 21; t <= 28; t++) _buildToothItem(t),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Cuadrantes Inferiores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Arcada Inferior (Cuadrantes 4 y 3)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int t = 48; t >= 41; t--) _buildToothItem(t),
                      Container(width: 2, height: 40, color: AppColors.primary, margin: const EdgeInsets.symmetric(horizontal: 8)),
                      for (int t = 31; t <= 38; t++) _buildToothItem(t),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Ficha de Pieza Dental Seleccionada
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary, width: 1.5),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ficha Dental: Pieza #$_selectedToothNumber',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getToothColor(_selectedToothNumber).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        infoTooth?['estado'] ?? 'Sano',
                        style: TextStyle(
                          color: _getToothColor(_selectedToothNumber),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildToothDetailRow('Diagnóstico:', infoTooth?['diagnostico'] ?? 'Sin diagnóstico'),
                _buildToothDetailRow('Tratamiento Requerido:', infoTooth?['tratamiento'] ?? 'Sin tratamiento'),
                _buildToothDetailRow('Etapa / Evolución:', infoTooth?['evolucion'] ?? 'Evaluación'),
                _buildToothDetailRow('Costo Estimado (GTQ):', 'Q ${(infoTooth?['precio_gtq'] ?? 0.0).toStringAsFixed(2)}'),
                _buildToothDetailRow('Notas Clínicas:', infoTooth?['notas'] ?? 'Sin observaciones'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _mostrarDialogoEdicionPieza(_selectedToothNumber),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar Tratamiento de Pieza'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }

  Widget _buildToothItem(int toothNum) {
    final isSelected = toothNum == _selectedToothNumber;
    final color = _getToothColor(toothNum);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedToothNumber = toothNum;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : color,
            width: isSelected ? 2.5 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.shield_outlined, size: 20, color: color == AppColors.surfaceContainerLow ? AppColors.textLight : color),
            const SizedBox(height: 4),
            Text(
              '$toothNum',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToothDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface))),
        ],
      ),
    );
  }

  // TAB 2: TRATAMIENTOS ACTIVOS & PLAN FINANCIERO (GTQ Q)
  Widget _buildTratamientosActivosTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        // Presupuesto Resumen Card (GTQ Q)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ESTADO DE CUENTA (GTQ)', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Q ${_calcularTotal().toStringAsFixed(2)}', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('PAGADO: Q 2,500.00', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('PENDIENTE: Q 2,100.00', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ..._odontogramState.entries.where((e) => e.value["tratamiento"] != "" && e.value["tratamiento"] != "Ninguno").map((e) {
          final String evo = e.value["evolucion"] ?? "Evaluaci�n";
          return _buildTratamientoCard(
            nombre: "${e.value["tratamiento"]} (Pieza ${e.key})",
            estado: e.value["estado"] as String,
            estadoColor: _getToothColor(e.key),
            precioGtq: (e.value["precio_gtq"] as num).toDouble(),
            etapas: ["Evaluaci�n", "Presupuesto", "En Proceso", "Terminado"].map((stage) {
                if (stage == evo) return "$stage ?";
                return stage;
            }).toList(),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTratamientoCard({
    required String nombre,
    required String estado,
    required Color estadoColor,
    required double precioGtq,
    required List<String> etapas,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  estado,
                  style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Costo del Tratamiento: Q ${precioGtq.toStringAsFixed(2)} GTQ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: etapas.map((e) {
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 11, color: AppColors.textDark)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: ESTÉTICA FACIAL (Bichectomía & Lipopapada)
  Widget _buildEsteticaFacialTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowSoft, blurRadius: 18, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.face_retouching_natural, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text('Bichectomía & Perfilado Facial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Procedimiento quirúrgico menor para reducción de bolsas grasas de Bichat y afinamiento del tercio inferior del rostro.', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 14),

              // Pipeline de Bichectomía
              const Text('Flujo Clínico del Paciente:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPipelineStep('Valoración', true),
                    _buildPipelineStep('Presupuesto', true),
                    _buildPipelineStep('Consentimiento', true),
                    _buildPipelineStep('Cirugía', true),
                    _buildPipelineStep('Postoperatorio', true),
                    _buildPipelineStep('Control 7 días', false),
                    _buildPipelineStep('Alta', false),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowSoft, blurRadius: 18, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.spa_outlined, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text('Lipopapada Enzimática / Quirúrgica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Reducción del tejido graso submentoniano para definición de ángulo mandibular.', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 14),

              const Text('Flujo Clínico del Paciente:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPipelineStep('Valoración', true),
                    _buildPipelineStep('Presupuesto', true),
                    _buildPipelineStep('Sesión 1', true),
                    _buildPipelineStep('Control', false),
                    _buildPipelineStep('Alta', false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineStep(String label, bool completed) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: completed ? AppColors.primary.withOpacity(0.12) : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: completed ? AppColors.primary : AppColors.ghostOutline, width: 1),
      ),
      child: Text(
        '$label ${completed ? "✓" : "○"}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: completed ? FontWeight.bold : FontWeight.normal,
          color: completed ? AppColors.primary : AppColors.textLight,
        ),
      ),
    );
  }
}
