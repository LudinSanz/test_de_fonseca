import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final List<Map<String, dynamic>> _tratamientosEstetica = [];

  // Filtros de navegación
  String _filtroPlanCategoria = 'Todos';
  String _filtroEsteticaProcedimiento = 'Todos';

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

  bool _esProcedimientoEstetico(Map<String, dynamic> t) {
    final cat = (t['categoria']?.toString() ?? '').toLowerCase();
    if (cat == 'estetica_facial' || cat == 'estetica') return true;
    final nombre = (t['tratamiento']?.toString() ?? '').toLowerCase();
    return nombre.contains('lipopapada') ||
        nombre.contains('bichectom') ||
        nombre.contains('botox') ||
        nombre.contains('enzima') ||
        nombre.contains('perfilado') ||
        nombre.contains('armoniz');
  }

  Future<void> _cargarTratamientosDelPaciente(String pacienteId) async {
    setState(() {
      _isLoading = true;
      _odontogramState.clear();
      _tratamientosGenerales.clear();
      _tratamientosEstetica.clear();
    });
    try {
      final supabaseService = SupabaseService();
      final tratamientos = await supabaseService.obtenerTratamientos(pacienteId: pacienteId);
      for (var t in tratamientos) {
        int d = t["diente"] ?? 0;
        if (d > 0) {
          _odontogramState[d] = Map<String, dynamic>.from(t);
        } else if (_esProcedimientoEstetico(t)) {
          _tratamientosEstetica.add(Map<String, dynamic>.from(t));
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
      if (_pacienteSeleccionado != null) {
        await _cargarTratamientosDelPaciente(_pacienteSeleccionado!.id);
      }
    } catch (e) {
      debugPrint('Error al cargar pacientes en Tratamientos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _cleanPhoneForWhatsApp(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (!clean.startsWith('502') && clean.length == 8) {
      clean = '502$clean';
    }
    return clean;
  }

  void _abrirWhatsApp(String phone, String mensaje) async {
    final cleanPhone = _cleanPhoneForWhatsApp(phone);
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(mensaje)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir WhatsApp para el número $cleanPhone'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _compartirTratamientoWhatsApp(Map<String, dynamic> trat) {
    if (_pacienteSeleccionado == null) return;
    final nombre = _pacienteSeleccionado!.nombre;
    final procedimiento = trat['tratamiento'] ?? 'Procedimiento Dental';
    final subtipo = trat['subtipo'] ?? '';
    final evo = trat['evolucion'] ?? 'En Proceso';
    final costo = ((trat['precio_gtq'] as num?) ?? 0.0).toDouble();
    final abono = ((trat['abono_gtq'] as num?) ?? 0.0).toDouble();
    final saldo = (costo - abono).clamp(0.0, double.infinity);
    final zona = trat['zona'] ?? trat['diagnostico'] ?? '';
    final notas = trat['notas'] ?? 'Seguir indicaciones del doctor.';

    final msg = '*CLÍNICA RIZO DENTAL - Control de Tratamiento* 🦷✨\n\n'
        'Estimado/a *$nombre*, le compartimos el resumen de su procedimiento:\n\n'
        '📋 *Tratamiento:* $procedimiento ${subtipo.isNotEmpty ? "($subtipo)" : ""}\n'
        '${zona.isNotEmpty ? "📍 *Zona / Detalle:* $zona\n" : ""}'
        '🏁 *Etapa Actual:* $evo\n'
        '💰 *Estado de Cuenta:*\n'
        '  • Costo Total: Q ${costo.toStringAsFixed(2)}\n'
        '  • Total Abonado: Q ${abono.toStringAsFixed(2)}\n'
        '  • Saldo Pendiente: Q ${saldo.toStringAsFixed(2)}\n\n'
        '📝 *Indicaciones Clínicas:* $notas\n\n'
        'Cualquier duda estamos a sus órdenes en Rizo Dental (+502 5981-6632).';

    _abrirWhatsApp(_pacienteSeleccionado!.telefono, msg);
  }

  // ==================== CÁLCULOS FINANCIEROS ====================
  double _calcularTotalPresupuesto() {
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
    for (var value in _tratamientosEstetica) {
      if (value["precio_gtq"] != null) {
        total += (value["precio_gtq"] as num).toDouble();
      }
    }
    return total;
  }

  double _calcularTotalAbonado() {
    double total = 0;
    _odontogramState.forEach((key, value) {
      if (value["abono_gtq"] != null) {
        total += (value["abono_gtq"] as num).toDouble();
      }
    });
    for (var value in _tratamientosGenerales) {
      if (value["abono_gtq"] != null) {
        total += (value["abono_gtq"] as num).toDouble();
      }
    }
    for (var value in _tratamientosEstetica) {
      if (value["abono_gtq"] != null) {
        total += (value["abono_gtq"] as num).toDouble();
      }
    }
    return total;
  }

  double _calcularSaldoPendiente() {
    final saldo = _calcularTotalPresupuesto() - _calcularTotalAbonado();
    return saldo < 0 ? 0.0 : saldo;
  }

  // ==================== LIMPIEZA DE PIEZA DENTAL ====================
  Future<void> _limpiarPiezaDental(int toothNum) async {
    final info = _odontogramState[toothNum];
    if (info != null && info['id'] != null && info['id'].toString().isNotEmpty) {
      final supabaseService = SupabaseService();
      await supabaseService.eliminarTratamiento(info['id'].toString());
    }
    setState(() {
      _odontogramState.remove(toothNum);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pieza #$toothNum restablecida a Sano (Sin tratamiento).'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarDialogoEdicionPieza(int toothNum) {
    final info = _odontogramState[toothNum] ?? {};
    final diagCtrl = TextEditingController(text: info["diagnostico"] ?? "");
    final precioCtrl = TextEditingController(text: info["precio_gtq"] != null ? info["precio_gtq"].toString() : "");
    final abonoCtrl = TextEditingController(text: info["abono_gtq"] != null ? info["abono_gtq"].toString() : "");
    final notasCtrl = TextEditingController(text: info["notas"] ?? "");

    String trat = info["tratamiento"] ?? "Ninguno";
    if (trat.isEmpty || trat == "Sin tratamiento") trat = "Ninguno";

    String evol = info["evolucion"] ?? "Evaluación";
    if (evol.isEmpty) evol = "Evaluación";

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Pieza Dental #$toothNum", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18)),
              if (_odontogramState.containsKey(toothNum))
                IconButton(
                  tooltip: 'Limpiar Pieza (Marcar Sano)',
                  icon: const Icon(Icons.cleaning_services_outlined, color: AppColors.error),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Limpiar Pieza Dental'),
                        content: Text('¿Deseas desmarcar la pieza #$toothNum y restablecerla a Sano? Se eliminará el diagnóstico actual.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Limpiar', style: TextStyle(color: AppColors.error))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      Navigator.pop(ctx);
                      await _limpiarPiezaDental(toothNum);
                    }
                  },
                ),
            ],
          ),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (ctx, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: trat,
                      decoration: const InputDecoration(labelText: "Tratamiento Odontológico"),
                      items: [
                        "Limpieza Dental", "Extracción", "Endodoncia", "Corona", 
                        "Resina", "Blanqueamiento", "Ortodoncia", "Implante", "Carilla Estética", 
                        "Cirugía Tercer Molar", "Ninguno"
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
                    TextField(controller: diagCtrl, decoration: const InputDecoration(labelText: "Diagnóstico Clínico (ej. Caries oclusal)")),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precioCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Costo (GTQ Q)"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: abonoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Abono (GTQ Q)"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: notasCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Notas Clínicas / Materiales")),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (trat == "Ninguno") {
                  await _limpiarPiezaDental(toothNum);
                  if (mounted) Navigator.pop(ctx);
                  return;
                }

                final preciogtq = double.tryParse(precioCtrl.text) ?? 0.0;
                final abonogtq = double.tryParse(abonoCtrl.text) ?? 0.0;
                String estadoStr = "Pendiente";
                if (evol == "Terminado") estadoStr = "Tratado";
                if (evol == "Cancelado") estadoStr = "Sano";
                if (evol == "En Proceso") estadoStr = "Problema";

                final tratMap = {
                  "id": _odontogramState[toothNum]?["id"] ?? "",
                  "paciente_id": _pacienteSeleccionado?.id ?? "",
                  "diente": toothNum,
                  "categoria": "odontologia",
                  "diagnostico": diagCtrl.text,
                  "tratamiento": trat,
                  "evolucion": evol,
                  "precio_gtq": preciogtq,
                  "abono_gtq": abonogtq,
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
              child: const Text("Guardar Pieza"),
            ),
          ],
        );
      },
    );
  }

  // ==================== DIÁLOGO DE REGISTRO DE ABONO ====================
  void _mostrarDialogoAbono(Map<String, dynamic> trat) {
    final costo = ((trat['precio_gtq'] as num?) ?? 0.0).toDouble();
    final abonoActual = ((trat['abono_gtq'] as num?) ?? 0.0).toDouble();
    final saldoActual = (costo - abonoActual).clamp(0.0, double.infinity);

    final abonoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            "Registrar Abono • ${trat['tratamiento']}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Costo Total:', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        Text('Q ${costo.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Abonado Previo:', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        Text('Q ${abonoActual.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success)),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo Restante:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Text('Q ${saldoActual.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: abonoCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: "Monto a Abonar Hoy (GTQ Q)",
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      label: const Text('+ Q100'),
                      onPressed: () => abonoCtrl.text = '100',
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: const Text('+ Q250'),
                      onPressed: () => abonoCtrl.text = '250',
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: const Text('+ Q500'),
                      onPressed: () => abonoCtrl.text = '500',
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: Text('Saldar (Q ${saldoActual.toStringAsFixed(0)})'),
                      onPressed: () => abonoCtrl.text = saldoActual.toStringAsFixed(2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                final monto = double.tryParse(abonoCtrl.text) ?? 0.0;
                if (monto <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa un monto válido para abonar')),
                  );
                  return;
                }
                final nuevoAbono = abonoActual + monto;
                trat['abono_gtq'] = nuevoAbono;
                if (nuevoAbono >= costo && costo > 0) {
                  trat['estado'] = 'Completado';
                }

                final supabaseService = SupabaseService();
                await supabaseService.guardarTratamiento(trat);

                if (_pacienteSeleccionado != null) {
                  await _cargarTratamientosDelPaciente(_pacienteSeleccionado!.id);
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Abono de Q ${monto.toStringAsFixed(2)} registrado exitosamente.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text("Confirmar Abono"),
            ),
          ],
        );
      },
    );
  }

  // ==================== AVANZAR O CAMBIAR ETAPA ====================
  Future<void> _cambiarEtapaTratamiento(Map<String, dynamic> trat, String nuevaEtapa) async {
    final List<String> etapas = (trat['etapas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        ['Valoración', 'Presupuesto', 'Procedimiento', 'Control', 'Alta'];
    
    final nuevoIndex = etapas.indexOf(nuevaEtapa);

    setState(() {
      trat['evolucion'] = nuevaEtapa;
      if (nuevoIndex != -1) {
        trat['etapa_actual_index'] = nuevoIndex;
      }
      if (nuevaEtapa.toLowerCase().contains('alta') || nuevaEtapa.toLowerCase().contains('terminado')) {
        trat['estado'] = 'Completado';
      } else {
        trat['estado'] = 'En Proceso';
      }
    });

    final supabaseService = SupabaseService();
    await supabaseService.guardarTratamiento(trat);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Etapa actualizada a: $nuevaEtapa'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _avanzarSiguienteEtapa(Map<String, dynamic> trat) async {
    final List<String> etapas = (trat['etapas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        ['Valoración', 'Presupuesto', 'Consentimiento', 'Procedimiento', 'Control', 'Alta'];

    final actual = trat['evolucion'] ?? etapas.first;
    int idx = etapas.indexOf(actual);
    if (idx == -1) idx = 0;

    if (idx < etapas.length - 1) {
      final proximaEtapa = etapas[idx + 1];
      await _cambiarEtapaTratamiento(trat, proximaEtapa);
    } else {
      // Ya estaba en la última etapa
      setState(() {
        trat['estado'] = 'Completado';
      });
      final supabaseService = SupabaseService();
      await supabaseService.guardarTratamiento(trat);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Procedimiento culminado y dado de Alta exitosamente!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ==================== DIÁLOGO GESTIÓN ESTÉTICA FACIAL (LIPOPAPADA & BICHECTOMÍA) ====================
  void _mostrarDialogoEsteticaFacial({Map<String, dynamic>? tratamientoEdit, String? plantillaInicial}) {
    final isEditing = tratamientoEdit != null;

    final Map<String, List<String>> plantillasEtapas = {
      'Lipopapada Enzimática': [
        'Valoración Facial & Marcaje',
        'Presupuesto & Cuotas',
        'Consentimiento Informado',
        'Sesión 1 (Aplicación Enzimática)',
        'Control Inflamatorio (15 días)',
        'Sesión 2 (Refuerzo / Opcional)',
        'Alta Definitiva'
      ],
      'Lipopapada Quirúrgica': [
        'Valoración Quirúrgica',
        'Presupuesto & Preoperatorios',
        'Consentimiento Quirúrgico',
        'Intervención Quirúrgica',
        'Drenaje y Mentonera Elástica',
        'Control 7 días (Retiro Suturas)',
        'Alta Definitiva'
      ],
      'Bichectomía Bilateral': [
        'Valoración & Fotografía',
        'Presupuesto & Exámenes Sangre',
        'Consentimiento Quirúrgico',
        'Cirugía Ambulatoria Bilateral',
        'Control 48 Horas (Crioterapia)',
        'Retiro de Puntos (7 a 10 días)',
        'Alta & Control 30 días'
      ],
      'Toxina Botulínica ATM (Bruxismo)': [
        'Evaluación Palpatoria ATM',
        'Presupuesto',
        'Consentimiento Informado',
        'Aplicación Maseteros y Temporales',
        'Control de Fuerza Oclusal (14 días)',
        'Alta Semestral'
      ],
      'Armonización Orofacial / Perfilado': [
        'Valoración Estética 3D',
        'Presupuesto',
        'Consentimiento Informado',
        'Aplicación de Relleno / Ácido Hialurónico',
        'Control 15 días',
        'Alta'
      ],
    };

    String tipoProcedimiento = tratamientoEdit?['tratamiento'] ?? plantillaInicial ?? 'Lipopapada Enzimática';
    if (!plantillasEtapas.containsKey(tipoProcedimiento)) {
      tipoProcedimiento = 'Lipopapada Enzimática';
    }

    List<String> etapasDisponibles = (tratamientoEdit?['etapas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        plantillasEtapas[tipoProcedimiento]!;

    final subtipoCtrl = TextEditingController(text: tratamientoEdit?['subtipo'] ?? (tipoProcedimiento == 'Lipopapada Enzimática' ? 'PB Serum / Desoxicolato' : (tipoProcedimiento == 'Bichectomía Bilateral' ? 'Resección Bolsas de Bichat' : '')));
    final diagCtrl = TextEditingController(text: tratamientoEdit?['diagnostico'] ?? '');
    final zonaCtrl = TextEditingController(text: tratamientoEdit?['zona'] ?? (tipoProcedimiento.contains('Lipopapada') ? 'Submentón y reborde mandibular' : (tipoProcedimiento.contains('Bichectomía') ? 'Bolsas de Bichat bilaterales' : 'Maseteros y ATM')));
    final precioCtrl = TextEditingController(text: tratamientoEdit?['precio_gtq'] != null ? tratamientoEdit!['precio_gtq'].toString() : '');
    final abonoCtrl = TextEditingController(text: tratamientoEdit?['abono_gtq'] != null ? tratamientoEdit!['abono_gtq'].toString() : '');
    final notasCtrl = TextEditingController(text: tratamientoEdit?['notas'] ?? '');

    String evolActual = tratamientoEdit?['evolucion'] ?? etapasDisponibles.first;
    if (!etapasDisponibles.contains(evolActual)) {
      evolActual = etapasDisponibles.first;
    }

    String estadoActual = tratamientoEdit?['estado'] ?? 'En Proceso';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            isEditing ? "Gestionar: ${tratamientoEdit?['tratamiento']}" : "Nuevo Procedimiento de Estética Facial",
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 17),
          ),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (ctx, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isEditing) ...[
                      DropdownButtonFormField<String>(
                        value: tipoProcedimiento,
                        decoration: const InputDecoration(labelText: "Seleccionar Procedimiento"),
                        items: plantillasEtapas.keys.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              tipoProcedimiento = val;
                              etapasDisponibles = plantillasEtapas[val]!;
                              evolActual = etapasDisponibles.first;
                              if (val == 'Lipopapada Enzimática') {
                                subtipoCtrl.text = 'PB Serum / Desoxicolato';
                                zonaCtrl.text = 'Submentón y contorno mandibular';
                                precioCtrl.text = '1800';
                              } else if (val == 'Lipopapada Quirúrgica') {
                                subtipoCtrl.text = 'Microcánulas / Aspiración';
                                zonaCtrl.text = 'Región submentoniana';
                                precioCtrl.text = '2800';
                              } else if (val == 'Bichectomía Bilateral') {
                                subtipoCtrl.text = 'Extracción Bolsas Grasas de Bichat';
                                zonaCtrl.text = 'Bolsas de Bichat bilaterales';
                                precioCtrl.text = '3500';
                              } else if (val.contains('Botox')) {
                                subtipoCtrl.text = 'Toxina Botulínica Tipo A 50 UI';
                                zonaCtrl.text = 'Músculos maseteros y temporales';
                                precioCtrl.text = '1500';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    TextField(
                      controller: subtipoCtrl,
                      decoration: const InputDecoration(labelText: "Técnica / Producto Utilizado"),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: evolActual,
                      decoration: const InputDecoration(labelText: "Etapa Clínica Actual"),
                      items: etapasDisponibles.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => evolActual = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: estadoActual,
                      decoration: const InputDecoration(labelText: "Estado del Procedimiento"),
                      items: ["Pendiente", "En Proceso", "Completado", "Cancelado"]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => estadoActual = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: zonaCtrl,
                      decoration: const InputDecoration(labelText: "Zona Anatómica / Detalle"),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precioCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Costo Total (GTQ Q)"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: abonoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Abono Inicial (GTQ Q)"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: diagCtrl,
                      decoration: const InputDecoration(labelText: "Diagnóstico Clínico Facial"),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: notasCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: "Recomendaciones Post-tratamiento / Cuidados"),
                    ),
                  ],
                );
              },
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Eliminar procedimiento',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Eliminar Procedimiento'),
                      content: const Text('¿Estás seguro de eliminar este procedimiento estético? Esta acción no se puede deshacer.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final id = tratamientoEdit!['id'] as String;
                    final supabaseService = SupabaseService();
                    await supabaseService.eliminarTratamiento(id);
                    if (_pacienteSeleccionado != null) {
                      await _cargarTratamientosDelPaciente(_pacienteSeleccionado!.id);
                    }
                    if (mounted) Navigator.pop(ctx);
                  }
                },
              )
            else
              const SizedBox.shrink(),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () async {
                    final preciogtq = double.tryParse(precioCtrl.text) ?? 0.0;
                    final abonogtq = double.tryParse(abonoCtrl.text) ?? 0.0;

                    final tratMap = {
                      "id": isEditing ? tratamientoEdit!["id"] : "",
                      "paciente_id": _pacienteSeleccionado?.id ?? "",
                      "diente": 0,
                      "categoria": "estetica_facial",
                      "tratamiento": tipoProcedimiento,
                      "subtipo": subtipoCtrl.text,
                      "diagnostico": diagCtrl.text,
                      "zona": zonaCtrl.text,
                      "evolucion": evolActual,
                      "etapas": etapasDisponibles,
                      "etapa_actual_index": etapasDisponibles.indexOf(evolActual),
                      "precio_gtq": preciogtq,
                      "abono_gtq": abonogtq,
                      "estado": estadoActual,
                      "notas": notasCtrl.text,
                      "fecha": isEditing ? (tratamientoEdit!["fecha"] ?? DateTime.now().toIso8601String()) : DateTime.now().toIso8601String(),
                    };

                    final supabaseService = SupabaseService();
                    await supabaseService.guardarTratamiento(tratMap);

                    if (_pacienteSeleccionado != null) {
                      await _cargarTratamientosDelPaciente(_pacienteSeleccionado!.id);
                    }

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$tipoProcedimiento guardado exitosamente.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: const Text("Guardar Procedimiento"),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ==================== DIÁLOGO TRATAMIENTO LIBRE / GENERAL ====================
  void _mostrarDialogoPlanTratamiento({Map<String, dynamic>? tratamientoEdit}) {
    final isEditing = tratamientoEdit != null;
    final diagCtrl = TextEditingController(text: tratamientoEdit?["diagnostico"] ?? "");
    final precioCtrl = TextEditingController(text: tratamientoEdit?["precio_gtq"] != null ? tratamientoEdit!["precio_gtq"].toString() : "");
    final abonoCtrl = TextEditingController(text: tratamientoEdit?["abono_gtq"] != null ? tratamientoEdit!["abono_gtq"].toString() : "");
    final notasCtrl = TextEditingController(text: tratamientoEdit?["notas"] ?? "");
    final nombreCtrl = TextEditingController(text: tratamientoEdit?["tratamiento"] ?? "");

    String evol = tratamientoEdit?["evolucion"] ?? "Evaluación";
    if (evol.isEmpty) evol = "Evaluación";

    String estadoGeneral = tratamientoEdit?["estado"] ?? "Pendiente";
    if (estadoGeneral.isEmpty) estadoGeneral = "Pendiente";

    String categoria = tratamientoEdit?['categoria'] ?? "general";

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(isEditing ? "Editar Tratamiento General" : "Nuevo Tratamiento General / ATM", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (ctx, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Procedimiento / Tratamiento")),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: categoria,
                      decoration: const InputDecoration(labelText: "Categoría"),
                      items: const [
                        DropdownMenuItem(value: "general", child: Text("General / Preventivo")),
                        DropdownMenuItem(value: "atm", child: Text("ATM / Articular")),
                        DropdownMenuItem(value: "odontologia", child: Text("Odontología Especializada")),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => categoria = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: estadoGeneral,
                      decoration: const InputDecoration(labelText: "Estado del Tratamiento"),
                      items: ["Pendiente", "En Proceso", "Completado", "Cancelado"]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => estadoGeneral = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: evol,
                      decoration: const InputDecoration(labelText: "Etapa Administrativa / Clínica"),
                      items: ["Evaluación", "Presupuesto", "En Proceso", "Terminado", "Cancelado"]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => evol = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: diagCtrl, decoration: const InputDecoration(labelText: "Diagnóstico / Motivo")),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precioCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Costo Total (GTQ)"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: abonoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Abono (GTQ)"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: notasCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Notas / Observaciones")),
                  ],
                );
              },
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Eliminar Tratamiento'),
                      content: const Text('¿Estás seguro de eliminar este tratamiento?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final id = tratamientoEdit!['id'] as String;
                    final supabaseService = SupabaseService();
                    await supabaseService.eliminarTratamiento(id);
                    if (_pacienteSeleccionado != null) {
                      await _cargarTratamientosDelPaciente(_pacienteSeleccionado!.id);
                    }
                    if (mounted) Navigator.pop(ctx);
                  }
                },
              )
            else
              const SizedBox.shrink(),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nombreCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes introducir un nombre para el procedimiento')));
                      return;
                    }

                    final preciogtq = double.tryParse(precioCtrl.text) ?? 0.0;
                    final abonogtq = double.tryParse(abonoCtrl.text) ?? 0.0;

                    final tratMap = {
                      "id": isEditing ? tratamientoEdit!["id"] : "",
                      "paciente_id": _pacienteSeleccionado?.id ?? "",
                      "diente": 0,
                      "categoria": categoria,
                      "diagnostico": diagCtrl.text,
                      "tratamiento": nombreCtrl.text,
                      "evolucion": evol,
                      "precio_gtq": preciogtq,
                      "abono_gtq": abonogtq,
                      "estado": estadoGeneral,
                      "notas": notasCtrl.text,
                      "fecha": isEditing ? (tratamientoEdit!["fecha"] ?? DateTime.now().toIso8601String()) : DateTime.now().toIso8601String(),
                    };

                    final supabaseService = SupabaseService();
                    await supabaseService.guardarTratamiento(tratMap);

                    if (_pacienteSeleccionado != null) {
                      await _cargarTratamientosDelPaciente(_pacienteSeleccionado!.id);
                    }

                    if (mounted) Navigator.pop(ctx);
                  },
                  child: const Text("Guardar"),
                ),
              ],
            )
          ],
        );
      },
    );
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
                  'Gestión Clínica • Odontograma • Lipopapada • Bichectomía',
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
                    padding: const EdgeInsets.all(14),
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
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
                      tabs: [
                        Tab(text: 'Odontograma (${_odontogramState.length})'),
                        Tab(text: 'Plan General (${_odontogramState.length + _tratamientosGenerales.length + _tratamientosEstetica.length})'),
                        Tab(text: 'Estética & Lipopapada (${_tratamientosEstetica.length})'),
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

  // ==================== TAB 1: ODONTOGRAMA INTERACTIVO ====================
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

  Widget _buildOdontogramaTab() {
    final infoTooth = _odontogramState[_selectedToothNumber];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leyenda de Colores del Odontograma
          Container(
            padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 12),

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
          const SizedBox(height: 12),

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
          const SizedBox(height: 14),

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
                _buildToothDetailRow('Costo Estimado (GTQ):', 'Q ${((infoTooth?['precio_gtq'] as num?) ?? 0.0).toStringAsFixed(2)}'),
                _buildToothDetailRow('Abonado a la Fecha:', 'Q ${((infoTooth?['abono_gtq'] as num?) ?? 0.0).toStringAsFixed(2)}'),
                _buildToothDetailRow('Notas Clínicas:', infoTooth?['notas'] ?? 'Sin observaciones'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _mostrarDialogoEdicionPieza(_selectedToothNumber),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Gestionar Pieza'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (infoTooth != null && infoTooth['tratamiento'] != null && infoTooth['tratamiento'] != "Ninguno") ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Limpiar Pieza (Sano)',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerLow,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.cleaning_services_outlined, color: AppColors.error),
                        onPressed: () => _limpiarPiezaDental(_selectedToothNumber),
                      ),
                    ],
                  ],
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
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface))),
        ],
      ),
    );
  }

  // ==================== TAB 2: PLAN DE TRATAMIENTO GENERAL ====================
  Widget _buildPlanTratamientoTab() {
    final todosTratamientos = <Map<String, dynamic>>[];
    
    // 1. Agregar odontograma
    _odontogramState.forEach((key, value) {
      if (value["tratamiento"] != "" && value["tratamiento"] != "Ninguno" && value["tratamiento"] != "Sin tratamiento") {
        final t = Map<String, dynamic>.from(value);
        t['is_odontogram'] = true;
        t['categoria'] = 'odontologia';
        todosTratamientos.add(t);
      }
    });
    
    // 2. Agregar generales
    for (var t in _tratamientosGenerales) {
      final copy = Map<String, dynamic>.from(t);
      copy['is_odontogram'] = false;
      if (copy['categoria'] == null) copy['categoria'] = 'general';
      todosTratamientos.add(copy);
    }

    // 3. Agregar estética facial
    for (var t in _tratamientosEstetica) {
      final copy = Map<String, dynamic>.from(t);
      copy['is_odontogram'] = false;
      copy['categoria'] = 'estetica_facial';
      todosTratamientos.add(copy);
    }
    
    // Filtrar según categoría seleccionada
    final filtrados = todosTratamientos.where((t) {
      if (_filtroPlanCategoria == 'Todos') return true;
      if (_filtroPlanCategoria == 'Odontología' && t['categoria'] == 'odontologia') return true;
      if (_filtroPlanCategoria == 'Estética Facial' && t['categoria'] == 'estetica_facial') return true;
      if (_filtroPlanCategoria == 'ATM' && (t['categoria'] == 'atm' || t['tratamiento'].toString().toLowerCase().contains('atm'))) return true;
      return false;
    }).toList();

    filtrados.sort((a, b) {
      final fa = a['fecha']?.toString() ?? '';
      final fb = b['fecha']?.toString() ?? '';
      return fb.compareTo(fa);
    });

    final totalPresupuesto = _calcularTotalPresupuesto();
    final totalAbonado = _calcularTotalAbonado();
    final saldoPendiente = _calcularSaldoPendiente();
    final double progresoPago = totalPresupuesto > 0 ? (totalAbonado / totalPresupuesto).clamp(0.0, 1.0) : 0.0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        // Botón para agregar tratamiento
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Agregar Tratamiento Libre / ATM'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _mostrarDialogoPlanTratamiento(),
        ),
        const SizedBox(height: 14),
        
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ESTADO DE CUENTA CLÍNICO (GTQ)', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Plan', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text('Q ${totalPresupuesto.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Abonado', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text('Q ${totalAbonado.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Saldo', style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text('Q ${saldoPendiente.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progresoPago,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF69F0AE)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${(progresoPago * 100).toStringAsFixed(0)}% cubierto', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Filtros de categoría
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Todos', 'Odontología', 'Estética Facial', 'ATM'].map((cat) {
              final isSel = _filtroPlanCategoria == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat, style: TextStyle(color: isSel ? Colors.white : AppColors.onSurface, fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                  selected: isSel,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceContainerLow,
                  onSelected: (val) {
                    if (val) setState(() => _filtroPlanCategoria = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Lista de tratamientos
        ...filtrados.map((t) {
          final String estadoStr = t["estado"] ?? "Pendiente";
          final bool isOdonto = t['is_odontogram'] == true;
          final int diente = t['diente'] ?? 0;
          final String cat = t['categoria'] ?? 'general';
          final double costo = ((t['precio_gtq'] as num?) ?? 0.0).toDouble();
          final double abono = ((t['abono_gtq'] as num?) ?? 0.0).toDouble();
          final double saldo = (costo - abono).clamp(0.0, double.infinity);

          Color estadoColor = AppColors.surfaceContainerLow;
          if (estadoStr == 'Pendiente') estadoColor = AppColors.warning;
          if (estadoStr == 'Problema' || estadoStr == 'En Proceso') estadoColor = AppColors.error;
          if (estadoStr == 'Tratado' || estadoStr == 'Completado') estadoColor = AppColors.success;
          if (estadoStr == 'Cancelado') estadoColor = AppColors.textLight;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cat == 'estetica_facial' ? AppColors.primaryContainer.withOpacity(0.15) : (cat == 'atm' ? Colors.deepPurple.withOpacity(0.12) : AppColors.primary.withOpacity(0.12)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  cat == 'estetica_facial' ? 'ESTÉTICA FACIAL' : (cat == 'atm' ? 'ATM' : 'ODONTOLOGÍA'),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: cat == 'estetica_facial' ? AppColors.primaryContainer : (cat == 'atm' ? Colors.deepPurple : AppColors.primary),
                                  ),
                                ),
                              ),
                              if (isOdonto) ...[
                                const SizedBox(width: 6),
                                Text('Pieza #$diente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t['tratamiento'] ?? 'Tratamiento',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        estadoStr,
                        style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                if ((t['diagnostico']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Dx: ${t['diagnostico']}', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                ],
                const SizedBox(height: 8),

                // Balance financiero
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Costo: Q ${costo.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                      Text('Abono: Q ${abono.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                      Text('Saldo: Q ${saldo.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: saldo > 0 ? AppColors.error : AppColors.success)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Botones de acción rápida
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.attach_money, size: 16, color: AppColors.primary),
                        label: const Text('Abonar', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        onPressed: () => _mostrarDialogoAbono(t),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Compartir WhatsApp',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366).withOpacity(0.12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 18),
                      onPressed: () => _compartirTratamientoWhatsApp(t),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Editar Ficha',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerLow,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                      onPressed: () {
                        if (isOdonto) {
                          setState(() {
                            _tabController.index = 0;
                            _selectedToothNumber = diente;
                          });
                          _mostrarDialogoEdicionPieza(diente);
                        } else if (cat == 'estetica_facial') {
                          _mostrarDialogoEsteticaFacial(tratamientoEdit: t);
                        } else {
                          _mostrarDialogoPlanTratamiento(tratamientoEdit: t);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),

        if (filtrados.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'No hay tratamientos registrados en esta categoría.',
                style: TextStyle(color: AppColors.textLight),
              ),
            ),
          ),
      ],
    );
  }

  // ==================== TAB 3: ESTÉTICA FACIAL & LIPOPAPADA GESTIONABLE ====================
  Widget _buildEsteticaFacialTab() {
    final filtrados = _tratamientosEstetica.where((t) {
      if (_filtroEsteticaProcedimiento == 'Todos') return true;
      final trat = (t['tratamiento']?.toString() ?? '').toLowerCase();
      if (_filtroEsteticaProcedimiento == 'Lipopapada' && trat.contains('lipopapada')) return true;
      if (_filtroEsteticaProcedimiento == 'Bichectomía' && trat.contains('bichectom')) return true;
      if (_filtroEsteticaProcedimiento == 'Botox ATM' && trat.contains('botox')) return true;
      if (_filtroEsteticaProcedimiento == 'Otros') {
        return !trat.contains('lipopapada') && !trat.contains('bichectom') && !trat.contains('botox');
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        // Botón principal: "+ Nuevo Procedimiento Estético"
        ElevatedButton.icon(
          icon: const Icon(Icons.face_retouching_natural, size: 20),
          label: const Text('+ Nuevo Procedimiento Estético Facial'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _mostrarDialogoEsteticaFacial(),
        ),
        const SizedBox(height: 12),

        // Filtro por tipo de procedimiento
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Todos', 'Lipopapada', 'Bichectomía', 'Botox ATM', 'Otros'].map((proc) {
              final isSel = _filtroEsteticaProcedimiento == proc;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(proc, style: TextStyle(color: isSel ? Colors.white : AppColors.onSurface, fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                  selected: isSel,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceContainerLow,
                  onSelected: (val) {
                    if (val) setState(() => _filtroEsteticaProcedimiento = proc);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Tarjetas dinámicas e interactivas de procedimientos
        ...filtrados.map((t) {
          final String nombre = t['tratamiento'] ?? 'Procedimiento Estético';
          final String subtipo = t['subtipo'] ?? '';
          final String evoActual = t['evolucion'] ?? 'Valoración';
          final String estadoStr = t['estado'] ?? 'En Proceso';
          final String zona = t['zona'] ?? '';
          final String notas = t['notas'] ?? '';
          final double costo = ((t['precio_gtq'] as num?) ?? 0.0).toDouble();
          final double abono = ((t['abono_gtq'] as num?) ?? 0.0).toDouble();
          final double saldo = (costo - abono).clamp(0.0, double.infinity);

          final List<String> etapas = (t['etapas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              ['Valoración', 'Presupuesto', 'Consentimiento', 'Procedimiento', 'Control', 'Alta'];

          final int stepIndexActual = etapas.indexOf(evoActual);

          Color estadoColor = AppColors.warning;
          if (estadoStr == 'Completado') estadoColor = AppColors.success;
          if (estadoStr == 'En Proceso') estadoColor = AppColors.primary;
          if (estadoStr == 'Cancelado') estadoColor = AppColors.textLight;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.2),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowSoft, blurRadius: 18, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera: Título, ícono y badge de estado
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      radius: 20,
                      child: Icon(
                        nombre.toLowerCase().contains('lipopapada') ? Icons.spa_outlined : Icons.face_retouching_natural,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.onSurface)),
                          if (subtipo.isNotEmpty)
                            Text(subtipo, style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        estadoStr,
                        style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                if (zona.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('Zona: $zona', style: const TextStyle(fontSize: 11, color: AppColors.onSurface, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Flujo Clínico Interactivo (Clickable Pipeline)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Flujo Clínico Interactivo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                    Text(
                      'Toca una etapa para actualizarla',
                      style: TextStyle(fontSize: 10, color: AppColors.textLight.withOpacity(0.8), fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: etapas.map((step) {
                      final int stepIndex = etapas.indexOf(step);
                      final bool isCompleted = stepIndex < stepIndexActual || estadoStr == 'Completado';
                      final bool isCurrent = stepIndex == stepIndexActual && estadoStr != 'Completado';

                      return GestureDetector(
                        onTap: () => _cambiarEtapaTratamiento(t, step),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.primary
                                : (isCompleted ? AppColors.primary.withOpacity(0.12) : AppColors.surfaceContainerLow),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCurrent ? AppColors.primary : (isCompleted ? AppColors.primary : AppColors.ghostOutline),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                step,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: (isCurrent || isCompleted) ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent ? Colors.white : ((isCompleted) ? AppColors.primary : AppColors.textLight),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCompleted ? "✓" : (isCurrent ? "★" : "○"),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : ((isCompleted) ? AppColors.primary : AppColors.textLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Tarjeta Financiera (Costo, Abono, Saldo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Costo Total', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                          Text('Q ${costo.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Total Abonado', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                          Text('Q ${abono.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Saldo Restante', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                          Text(
                            'Q ${saldo.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: saldo > 0 ? AppColors.error : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (notas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(notas, style: const TextStyle(fontSize: 11, color: AppColors.onSurface)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Barra de Acciones del Procedimiento
                Row(
                  children: [
                    // Botón para avanzar a siguiente etapa en 1 toque
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: estadoStr == 'Completado' ? AppColors.success : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(estadoStr == 'Completado' ? Icons.check_circle_outline : Icons.arrow_forward, size: 16),
                        label: Text(
                          estadoStr == 'Completado' ? 'Alta Completada' : 'Avanzar Etapa',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: estadoStr == 'Completado' ? null : () => _avanzarSiguienteEtapa(t),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Registrar Abono
                    IconButton(
                      tooltip: 'Registrar Abono',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.success.withOpacity(0.12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.attach_money, color: AppColors.success),
                      onPressed: () => _mostrarDialogoAbono(t),
                    ),
                    const SizedBox(width: 4),

                    // Compartir WhatsApp
                    IconButton(
                      tooltip: 'Enviar Estado por WhatsApp',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366).withOpacity(0.12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                      onPressed: () => _compartirTratamientoWhatsApp(t),
                    ),
                    const SizedBox(width: 4),

                    // Editar Ficha Completa
                    IconButton(
                      tooltip: 'Editar Ficha',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerLow,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                      onPressed: () => _mostrarDialogoEsteticaFacial(tratamientoEdit: t),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),

        // Estado vacío con botones rápidos para crear procedimientos
        if (filtrados.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.ghostOutline),
            ),
            child: Column(
              children: [
                const Icon(Icons.spa_outlined, color: AppColors.primary, size: 48),
                const SizedBox(height: 10),
                const Text(
                  'Sin Procedimientos Estéticos Activos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Inicia la gestión clínica de estética facial y perfilado para este paciente:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Lipopapada Enzimática'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _mostrarDialogoEsteticaFacial(plantillaInicial: 'Lipopapada Enzimática'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Bichectomía Bilateral'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _mostrarDialogoEsteticaFacial(plantillaInicial: 'Bichectomía Bilateral'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Botox ATM (Maseteros)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _mostrarDialogoEsteticaFacial(plantillaInicial: 'Toxina Botulínica ATM (Bruxismo)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
