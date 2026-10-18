import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';
import '../services/supabase_service.dart';
import 'patient_directory_screen.dart';

// ============================================================
// MODELO DE CONVERSACION
// ============================================================
class WaConversacion {
  final Paciente paciente;
  final List<Map<String, dynamic>> mensajes;
  final DateTime ultimaActividad;
  final int noLeidos;

  WaConversacion({
    required this.paciente,
    required this.mensajes,
    required this.ultimaActividad,
    this.noLeidos = 0,
  });
}

// ============================================================
// PANTALLA PRINCIPAL DE MENSAJES
// ============================================================
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final SupabaseService _db = SupabaseService();

  List<Paciente> _pacientes = [];
  Paciente? _pacienteSeleccionado;
  bool _loading = true;

  // Conversaciones simuladas por paciente (en produccion vendrian de Supabase o API WhatsApp)
  final Map<String, List<Map<String, dynamic>>> _conversaciones = {};

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPacientes() async {
    try {
      final lista = await _db.obtenerPacientes();
      setState(() {
        _pacientes = lista;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getMensajesPaciente(String pacienteId) {
    return _conversaciones[pacienteId] ?? [
      {
        'from': 'clinica',
        'text': 'Historial local de borradores de WhatsApp. (La aplicación prepara los mensajes, pero TÚ decides enviarlos o no desde WhatsApp).',
        'time': DateTime.now().subtract(const Duration(minutes: 5)),
        'tipo': 'sistema',
      }
    ];
  }

  void _agregarMensaje(String pacienteId, Map<String, dynamic> msg) {
    setState(() {
      if (!_conversaciones.containsKey(pacienteId)) {
        _conversaciones[pacienteId] = _getMensajesPaciente(pacienteId);
      }
      _conversaciones[pacienteId]!.add(msg);
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ============================================================
  // ABRIR WHATSAPP CON MENSAJE
  Future<void> _abrirWhatsApp(Paciente p, String mensaje) async {
    if (p.telefono.isEmpty || p.telefono.length < 8) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El paciente no tiene un teléfono válido registrado.')));
      }
      return;
    }

    String telefono = p.telefono.replaceAll(RegExp(r'[^\d\+]'), '');
    if (!telefono.startsWith('+')) {
      if (!telefono.startsWith('502') && !telefono.startsWith('503') && !telefono.startsWith('504') && !telefono.startsWith('505') && !telefono.startsWith('506') && !telefono.startsWith('507') && !telefono.startsWith('52') && !telefono.startsWith('1')) {
         telefono = "+502$telefono";
      } else {
         telefono = "+$telefono";
      }
    }
    
    final tel = telefono.replaceAll('+', '');
    final uri = Uri.parse('https://wa.me/$tel?text=${Uri.encodeComponent(mensaje)}');

    _agregarMensaje(p.id, {
      'from': 'clinica',
      'text': mensaje,
      'time': DateTime.now(),
      'tipo': 'preparado',
    });

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp. Verifica que esté instalado.')),
        );
      }
    }
  }

  // ============================================================
  // MENU DE ACCIONES RAPIDAS
  // ============================================================
  void _mostrarAccionesRapidas(Paciente p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AccionesRapidasSheet(
        paciente: p,
        onEnviar: (mensaje, tipo) async {
          Navigator.pop(ctx);
          await _abrirWhatsApp(p, mensaje);
        },
        db: _db,
      ),
    );
  }

  // ============================================================
  // UI PRINCIPAL
  // ============================================================
  @override
    Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Centro de Mensajes", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text("WhatsApp Cl�nica", style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        leading: _pacienteSeleccionado != null && MediaQuery.of(context).size.width < 600
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _pacienteSeleccionado = null),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () { setState(() => _loading = true); _cargarPacientes(); },
            tooltip: "Actualizar",
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                if (isMobile) {
                  return _pacienteSeleccionado == null
                      ? _buildListaConversaciones(isMobile: true)
                      : _buildChat(_pacienteSeleccionado!);
                }
                return Row(
                  children: [
                    _buildListaConversaciones(isMobile: false),
                    Expanded(child: _pacienteSeleccionado == null ? _buildBienvenida() : _buildChat(_pacienteSeleccionado!)),
                  ],
                );
              },
            ),
    );
  }

  // ---- LISTA DE PACIENTES / CONVERSACIONES ----
  Widget _buildListaConversaciones({bool isMobile = false}) {
    return Container(
      width: isMobile ? double.infinity : 320,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Header lista
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar paciente...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7), size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
              ),
              onChanged: (val) => setState(() {}),
            ),
          ),
          // Lista de pacientes
          Expanded(
            child: _pacientes.isEmpty
                ? const Center(child: Text('Sin pacientes', style: TextStyle(color: Colors.grey, fontSize: 13)))
                : ListView.builder(
                    itemCount: _pacientes.length,
                    itemBuilder: (ctx, i) {
                      final p = _pacientes[i];
                      final isSelected = _pacienteSeleccionado?.id == p.id;
                      final msgs = _getMensajesPaciente(p.id);
                      final ultimo = msgs.isNotEmpty ? msgs.last['text'] as String : 'Toca para iniciar conversación';

                      return InkWell(
                        onTap: () => setState(() => _pacienteSeleccionado = p),
                        child: Container(
                          color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  '${p.nombre[0]}${p.apellido.isNotEmpty ? p.apellido[0] : ''}',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p.nombre} ${p.apellido}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: AppColors.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ultimo,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Icono WhatsApp
                              Icon(Icons.message, size: 14, color: isSelected ? AppColors.primary : Colors.grey.shade400),
                            ],
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

  // ---- PANTALLA DE BIENVENIDA ----
  Widget _buildBienvenida() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          const Text('Centro de Mensajes WhatsApp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111B21))),
          const SizedBox(height: 8),
          const Text(
            'Selecciona un paciente de la lista\npara ver su conversación y enviarle información.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Los mensajes se envían vía WhatsApp.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ---- PANEL DE CHAT ----
  Widget _buildChat(Paciente p) {
    final mensajes = _getMensajesPaciente(p.id);

    return Column(
      children: [
        // Header del chat
        _buildChatHeader(p),
        // Mensajes
        Expanded(
          child: Container(
            color: const Color(0xFFEAE6DF),
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: mensajes.length,
              itemBuilder: (ctx, i) => _buildBurbuja(mensajes[i]),
            ),
          ),
        ),
        // Acciones rápidas + input
        _buildBarraEntrada(p),
      ],
    );
  }

  Widget _buildChatHeader(Paciente p) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Text('${p.nombre[0]}${p.apellido.isNotEmpty ? p.apellido[0] : ''}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.nombre} ${p.apellido}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(p.telefono, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          // Botón ver expediente
          TextButton.icon(
            onPressed: () => _mostrarInfoPaciente(p),
            icon: const Icon(Icons.person_search_outlined, size: 16, color: Colors.white70),
            label: const Text('Expediente', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ),
          // Botón abrir whatsapp directo
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 18),
            tooltip: 'Abrir WhatsApp',
            onPressed: () => _abrirWhatsApp(p, ''),
          ),
        ],
      ),
    );
  }

  Widget _buildBurbuja(Map<String, dynamic> msg) {
    final esClinica = msg['from'] == 'clinica';
    final esSistema = msg['tipo'] == 'sistema';
    final texto = msg['text'] as String;
    final time = msg['time'] as DateTime;
    final hora = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (esSistema) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(texto, style: const TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center),
        ),
      );
    }

    return Align(
      alignment: esClinica ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: esClinica ? const Color(0xFFD9FDD3) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(esClinica ? 12 : 0),
            bottomRight: Radius.circular(esClinica ? 0 : 12),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!esClinica)
              const Text('Paciente', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
            Text(texto, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 2),
            Text(hora, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraEntrada(Paciente p) {
    return Container(
      color: const Color(0xFFF0F2F5),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // ACCIONES RÁPIDAS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipAccion(Icons.calendar_today_rounded, 'Cita', () => _enviarPlantilla(p, 'cita'), Colors.blue),
                _chipAccion(Icons.medication_outlined, 'Receta', () => _enviarPlantilla(p, 'receta'), Colors.green),
                _chipAccion(Icons.psychology_outlined, 'Consulta', () => _enviarPlantilla(p, 'evaluacion'), Colors.orange),
                _chipAccion(Icons.quiz_outlined, 'Test Fonseca', () => _enviarPlantilla(p, 'fonseca'), Colors.purple),
                _chipAccion(Icons.notifications_outlined, 'Recordatorio', () => _enviarPlantilla(p, 'recordatorio'), Colors.amber),
                _chipAccion(Icons.local_hospital_outlined, 'Postop', () => _enviarPlantilla(p, 'postop'), Colors.red),
                _chipAccion(Icons.more_horiz_rounded, 'Más opciones', () => _mostrarAccionesRapidas(p), AppColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // INPUT DE MENSAJE
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje para ${p.nombre}...',
                    hintStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  final texto = _msgCtrl.text.trim();
                  if (texto.isEmpty) return;
                  _abrirWhatsApp(p, texto);
                  _msgCtrl.clear();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipAccion(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ---- PLANTILLAS DE MENSAJES ----
  Future<void> _enviarPlantilla(Paciente p, String tipo) async {
    String msg = '';
    final nombre = p.nombre;

    switch (tipo) {
      case 'cita':
        // Obtener próxima cita
        final citas = await _db.obtenerCitas(pacienteId: p.id);
        final futuras = citas.where((c) => (c['estado'] ?? '') != 'Cancelada').toList();
        if (futuras.isNotEmpty) {
          final c = futuras.first;
          msg = '¡Hola $nombre! 👋\n\nLe recordamos su *cita en Rizo Dental*:\n\n'
              '📅 *Fecha:* ${c['fecha'] ?? ''}\n'
              '🕐 *Hora:* ${c['hora'] ?? ''}\n'
              '📋 *Motivo:* ${c['motivo'] ?? ''}\n\n'
              'Por favor confirme su asistencia respondiendo *SÍ* o llame al *+502 5981-6632*.\n\n'
              '_Rizo Dental_ 🦷';
        } else {
          msg = '¡Hola $nombre! 👋\n\nEn Rizo Dental tenemos disponibilidad para agendar su próxima cita.\n\nContáctenos al *+502 5981-6632* para coordinar. 🦷';
        }
        break;
      case 'receta':
        final recetas = await _db.obtenerRecetas(pacienteId: p.id);
        if (recetas.isNotEmpty) {
          final r = recetas.first;
          msg = '¡Hola $nombre! 🏥\n\n*Recordatorio de Medicación - Rizo Dental*\n\n'
              '💊 *Medicamentos:*\n${r['medicamentos'] ?? ''}\n\n'
              '📋 *Indicaciones:*\n${r['indicaciones'] ?? ''}\n\n'
              '_Dr. Ludin Solís | Rizo Dental_ 🦷';
        } else {
          msg = '¡Hola $nombre! En Rizo Dental le enviamos el recordatorio de seguimiento de su tratamiento. Consulte al *+502 5981-6632*. 🦷';
        }
        break;
      case 'evaluacion':
        msg = '¡Hola $nombre! 👋\n\nEl Dr. Solís le solicita responder una *consulta clínica* de su estado de salud bucal.\n\n'
            'Por favor contáctenos al *+502 5981-6632* o visite la clínica para realizarla.\n\n'
            '_Rizo Dental_ 🦷';
        break;
      case 'fonseca':
        msg = '¡Hola $nombre! 🦷\n\nLe invitamos a completar el *Test de Fonseca* para evaluar su disfunción temporomandibular (ATM).\n\n'
            'Puede realizarlo en nuestra próxima visita o coordinando una cita al *+502 5981-6632*.\n\n'
            '_Rizo Dental - Especialistas ATM_';
        break;
      case 'recordatorio':
        msg = '¡Hola $nombre! 👋\n\n*Recordatorio de Rizo Dental* 🦷\n\nRecuerde seguir las indicaciones de su tratamiento. Si tiene dudas, contáctenos al *+502 5981-6632*.\n\n_¡Que tenga un excelente día!_';
        break;
      case 'postop':
        msg = '¡Hola $nombre! 🏥\n\n*Cuidados Postoperatorios - Rizo Dental*\n\n'
            '✅ Aplicar hielo las primeras 24 hrs (15 min ON / 15 min OFF)\n'
            '✅ Tomar medicación según indicaciones\n'
            '✅ Dieta blanda los primeros días\n'
            '✅ No fumar ni consumir alcohol\n'
            '⚠️ Si hay sangrado excesivo o fiebre, llame al *+502 5981-6632*\n\n'
            '_Rizo Dental_ 🦷';
        break;
    }

    if (msg.isNotEmpty) {
      await _abrirWhatsApp(p, msg);
    }
  }

  // ---- INFO PACIENTE / EXPEDIENTE RESUMEN ----
  void _mostrarInfoPaciente(Paciente p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExpedienteResumenSheet(
        paciente: p,
        db: _db,
        onAbrirAccionesRapidas: () => _mostrarAccionesRapidas(p),
      ),
    );
  }
}

// ============================================================
// MODAL EXPEDIENTE RESUMEN (ÚLTIMO PROCEDIMIENTO Y ACTIVIDAD)
// ============================================================
class _ExpedienteResumenSheet extends StatefulWidget {
  final Paciente paciente;
  final SupabaseService db;
  final VoidCallback onAbrirAccionesRapidas;

  const _ExpedienteResumenSheet({
    required this.paciente,
    required this.db,
    required this.onAbrirAccionesRapidas,
  });

  @override
  State<_ExpedienteResumenSheet> createState() => _ExpedienteResumenSheetState();
}

class _ExpedienteResumenSheetState extends State<_ExpedienteResumenSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tratamientos = [];
  List<Map<String, dynamic>> _citas = [];
  List<Map<String, dynamic>> _recetas = [];
  List<Map<String, dynamic>> _evaluaciones = [];

  @override
  void initState() {
    super.initState();
    _cargarExpediente();
  }

  Future<void> _cargarExpediente() async {
    try {
      final results = await Future.wait([
        widget.db.obtenerTratamientos(pacienteId: widget.paciente.id),
        widget.db.obtenerCitas(pacienteId: widget.paciente.id),
        widget.db.obtenerRecetas(pacienteId: widget.paciente.id),
        widget.db.obtenerEvaluaciones(pacienteId: widget.paciente.id),
      ]);

      if (mounted) {
        setState(() {
          _tratamientos = results[0] as List<Map<String, dynamic>>;
          _citas = results[1] as List<Map<String, dynamic>>;
          _recetas = results[2] as List<Map<String, dynamic>>;
          _evaluaciones = results[3] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calcularEdad(DateTime fecha) {
    final now = DateTime.now();
    int edad = now.year - fecha.year;
    if (now.month < fecha.month || (now.month == fecha.month && now.day < fecha.day)) {
      edad--;
    }
    return edad < 0 ? 0 : edad;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paciente;
    final edad = _calcularEdad(p.fechaNacimiento);

    // Obtener último procedimiento / tratamiento
    Map<String, dynamic>? ultimoTratamiento = _tratamientos.isNotEmpty ? _tratamientos.first : null;
    Map<String, dynamic>? ultimaCita = _citas.isNotEmpty ? _citas.first : null;
    Map<String, dynamic>? ultimaReceta = _recetas.isNotEmpty ? _recetas.first : null;
    Map<String, dynamic>? ultimaEval = _evaluaciones.isNotEmpty ? _evaluaciones.first : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle superior
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Encabezado del paciente
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryContainer],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : ''}${p.apellido.isNotEmpty ? p.apellido[0].toUpperCase() : ''}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p.nombre} ${p.apellido}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$edad años (${p.genero}) • Tel: ${p.telefono}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                      ),
                      if (p.email.isNotEmpty)
                        Text(
                          p.email,
                          style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textLight),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppColors.ghostOutline),

          // Contenido principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      // ── TARJETA DESTACADA: ÚLTIMO PROCEDIMIENTO / TRATAMIENTO REALIZADO ──
                      const Text(
                        'ÚLTIMO PROCEDIMIENTO / TRATAMIENTO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (ultimoTratamiento != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.2),
                            boxShadow: const [
                              BoxShadow(color: AppColors.shadowSoft, blurRadius: 12, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.medical_services_rounded, color: AppColors.primary, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ultimoTratamiento['tratamiento'] ?? ultimoTratamiento['procedimiento'] ?? 'Procedimiento Dental',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface),
                                        ),
                                        if ((ultimoTratamiento['subtipo'] ?? '').isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            ultimoTratamiento['subtipo'],
                                            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Badge de estado
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (ultimoTratamiento['evolucion'] ?? ultimoTratamiento['estado'] ?? 'En Proceso')
                                              .toString()
                                              .toLowerCase()
                                              .contains('complet')
                                          ? AppColors.success.withOpacity(0.15)
                                          : AppColors.warning.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      ultimoTratamiento['evolucion'] ?? ultimoTratamiento['estado'] ?? 'En Proceso',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: (ultimoTratamiento['evolucion'] ?? ultimoTratamiento['estado'] ?? 'En Proceso')
                                                .toString()
                                                .toLowerCase()
                                                .contains('complet')
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Fecha y notas
                              Row(
                                children: [
                                  const Icon(Icons.event_outlined, size: 14, color: AppColors.textLight),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Fecha: ${ultimoTratamiento['fecha'] ?? 'Reciente'}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
                                  ),
                                  if (ultimoTratamiento['precio_gtq'] != null) ...[
                                    const Spacer(),
                                    Text(
                                      'Q ${ultimoTratamiento['precio_gtq']}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ],
                                ],
                              ),
                              if ((ultimoTratamiento['notas'] ?? ultimoTratamiento['observaciones'] ?? '').isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Observaciones: ${ultimoTratamiento['notas'] ?? ultimoTratamiento['observaciones']}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.onSurface, height: 1.4),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.ghostOutline),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.textLight, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Aún no hay procedimientos o tratamientos registrados para este paciente.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── RESUMEN DE ACTIVIDAD CLÍNICA ──
                      const Text(
                        'RESUMEN CLÍNICO RECIENTE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tarjeta Última Cita
                      _buildResumenCard(
                        icon: Icons.calendar_month_outlined,
                        titulo: 'Última Cita',
                        detalle: ultimaCita != null
                            ? '${ultimaCita['fecha'] ?? ''} a las ${ultimaCita['hora'] ?? ''}\nMotivo: ${ultimaCita['motivo'] ?? 'Consulta general'}'
                            : 'Sin citas registradas',
                        estado: ultimaCita != null ? (ultimaCita['estado'] ?? 'Programada') : null,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(height: 10),

                      // Tarjeta Última Receta
                      _buildResumenCard(
                        icon: Icons.medication_outlined,
                        titulo: 'Última Receta Médica',
                        detalle: ultimaReceta != null
                            ? 'Medicamentos: ${ultimaReceta['medicamentos'] ?? ''}\nIndicaciones: ${ultimaReceta['indicaciones'] ?? ''}'
                            : 'Sin recetas prescritas',
                        estado: ultimaReceta != null ? (ultimaReceta['fecha'] ?? 'Reciente') : null,
                        color: AppColors.info,
                      ),
                      const SizedBox(height: 10),

                      // Tarjeta Test Fonseca ATM
                      _buildResumenCard(
                        icon: Icons.assignment_turned_in_outlined,
                        titulo: 'Evaluación ATM (Fonseca)',
                        detalle: ultimaEval != null
                            ? 'Puntaje: ${ultimaEval['puntaje'] ?? ultimaEval['puntos'] ?? 'N/A'} pts • ${ultimaEval['diagnostico'] ?? ultimaEval['clasificacion'] ?? 'Completado'}'
                            : 'Sin evaluación ATM realizada',
                        estado: ultimaEval != null ? (ultimaEval['fecha'] ?? '') : null,
                        color: AppColors.primary,
                      ),

                      const SizedBox(height: 24),

                      // ── BOTÓN ACCESO EXPEDIENTE 360° COMPLETO ──
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Cierra bottom sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => PatientDirectoryScreen(selectedPatient: widget.paciente),
                            ),
                          );
                        },
                        icon: const Icon(Icons.badge_outlined, size: 20),
                        label: const Text(
                          'Ver Expediente 360° Completo',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Botón preparar mensaje
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onAbrirAccionesRapidas();
                        },
                        icon: const Icon(Icons.send_rounded, size: 18, color: AppColors.primary),
                        label: const Text(
                          'Preparar Recordatorio o Mensaje',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard({
    required IconData icon,
    required String titulo,
    required String detalle,
    String? estado,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ghostOutline),
        boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface)),
                    if (estado != null && estado.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          estado,
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOJA DE ACCIONES RAPIDAS AVANZADA
// ============================================================
class _AccionesRapidasSheet extends StatefulWidget {
  final Paciente paciente;
  final Function(String mensaje, String tipo) onEnviar;
  final SupabaseService db;

  const _AccionesRapidasSheet({
    required this.paciente,
    required this.onEnviar,
    required this.db,
  });

  @override
  State<_AccionesRapidasSheet> createState() => _AccionesRapidasSheetState();
}

class _AccionesRapidasSheetState extends State<_AccionesRapidasSheet> {
  final TextEditingController _mensajeLibreCtrl = TextEditingController();
  List<Map<String, dynamic>> _citas = [];
  List<Map<String, dynamic>> _recetas = [];
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final results = await Future.wait([
      widget.db.obtenerCitas(pacienteId: widget.paciente.id),
      widget.db.obtenerRecetas(pacienteId: widget.paciente.id),
    ]);
    setState(() {
      _citas = results[0] as List<Map<String, dynamic>>;
      _recetas = results[1] as List<Map<String, dynamic>>;
      _loadingData = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paciente;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text('${p.nombre[0]}${p.apellido.isNotEmpty ? p.apellido[0] : ''}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.nombre} ${p.apellido}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(p.telefono, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.message, size: 14, color: Color(0xFF25D366)),
                      SizedBox(width: 4),
                      Text('WhatsApp', style: TextStyle(fontSize: 11, color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          // Contenido
          Expanded(
            child: _loadingData
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _seccion('Recordatorios Rápidos', [
                          _accionBtn(Icons.calendar_today_rounded, 'Recordatorio de Cita', Colors.blue,
                              _citas.isNotEmpty ? '${_citas.first['fecha']} a las ${_citas.first['hora']}' : 'Sin cita registrada', () {
                            if (_citas.isNotEmpty) {
                              final c = _citas.first;
                              widget.onEnviar(
                                '¡Hola ${p.nombre}! Le recordamos su cita en *Rizo Dental* el ${c['fecha']} a las ${c['hora']}. Motivo: ${c['motivo'] ?? ''}. Confirme al *+502 5981-6632*. 🦷',
                                'cita',
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este paciente no tiene citas registradas')));
                            }
                          }),
                          _accionBtn(Icons.medication_outlined, 'Recordatorio de Medicación', Colors.green,
                              _recetas.isNotEmpty ? _recetas.first['medicamentos']?.toString().split('\n').first ?? '' : 'Sin receta registrada', () {
                            if (_recetas.isNotEmpty) {
                              final r = _recetas.first;
                              widget.onEnviar(
                                '¡Hola ${p.nombre}! Recordatorio de *medicación - Rizo Dental*:\n\n${r['medicamentos'] ?? ''}\n\n${r['indicaciones'] ?? ''}\n\n_Dr. Ludin Solís_ 🦷',
                                'receta',
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este paciente no tiene recetas registradas')));
                            }
                          }),
                          _accionBtn(Icons.nightlight_round_outlined, 'Uso Nocturno Férula', Colors.indigo,
                              'Recordatorio de férula miorrelajante', () {
                            widget.onEnviar(
                              '¡Hola ${p.nombre}! Recuerde colocar su *férula miorrelajante* antes de dormir esta noche. Importante para controlar el bruxismo. 🦷 _Rizo Dental_',
                              'recordatorio',
                            );
                          }),
                        ]),
                        const SizedBox(height: 16),
                        _seccion('Solicitudes Clínicas', [
                          _accionBtn(Icons.quiz_outlined, 'Completar Test de Fonseca', Colors.purple,
                              'Enviar solicitud de evaluación ATM', () {
                            widget.onEnviar(
                              '¡Hola ${p.nombre}! El Dr. Solís le solicita completar el *Test de Fonseca* en su próxima visita. Este test evalúa su disfunción temporomandibular. Coordine al *+502 5981-6632*. 🦷',
                              'fonseca',
                            );
                          }),
                          _accionBtn(Icons.psychology_outlined, 'Evaluación Clínica Rápida', Colors.orange,
                              'Solicitar que el paciente venga a evaluación', () {
                            widget.onEnviar(
                              '¡Hola ${p.nombre}! Le invitamos a una *evaluación clínica rápida* en Rizo Dental. Le tomaremos aproximadamente 20 minutos. Contáctenos al *+502 5981-6632* para coordinar. 🦷',
                              'evaluacion',
                            );
                          }),
                          _accionBtn(Icons.local_hospital_outlined, 'Instrucciones Postoperatorias', Colors.red,
                              'Enviar cuidados después del procedimiento', () {
                            widget.onEnviar(
                              '¡Hola ${p.nombre}! Indicaciones postoperatorias *Rizo Dental*:\n\n✅ Hielo 15min ON/OFF las primeras 24h\n✅ Medicación según indicaciones\n✅ Dieta blanda\n✅ No fumar\n⚠️ Sangrado o fiebre: llame al *+502 5981-6632*\n\n_Dr. Ludin Solís_ 🦷',
                              'postop',
                            );
                          }),
                        ]),
                        const SizedBox(height: 16),
                        // Mensaje libre
                        const Text('Mensaje Personalizado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _mensajeLibreCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Escribe un mensaje personalizado para ${p.nombre}...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final texto = _mensajeLibreCtrl.text.trim();
                              if (texto.isEmpty) return;
                              widget.onEnviar(texto, 'libre');
                            },
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Enviar vía WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface)),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  Widget _accionBtn(IconData icon, String titulo, Color color, String subtitulo, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if (subtitulo.isNotEmpty)
                    Text(subtitulo, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.send_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
