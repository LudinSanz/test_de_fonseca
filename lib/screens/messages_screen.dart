import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';
import '../services/supabase_service.dart';

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
        'text': 'Conversación iniciada. Usa los accesos rápidos para enviar información al paciente por WhatsApp.',
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
  // ============================================================
  Future<void> _abrirWhatsApp(Paciente p, String mensaje) async {
    final telefono = p.telefono.replaceAll(RegExp(r'[^\d]'), '');
    final tel = telefono.startsWith('502') ? telefono : '502$telefono';
    final uri = Uri.parse('https://wa.me/$tel?text=${Uri.encodeComponent(mensaje)}');

    _agregarMensaje(p.id, {
      'from': 'clinica',
      'text': mensaje,
      'time': DateTime.now(),
      'tipo': 'enviado',
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
            Text('Centro de Mensajes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('WhatsApp Clínica', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () { setState(() => _loading = true); _cargarPacientes(); },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // ---- LISTA DE CONVERSACIONES ----
                _buildListaConversaciones(),
                // ---- PANEL DE CHAT ----
                Expanded(child: _pacienteSeleccionado == null ? _buildBienvenida() : _buildChat(_pacienteSeleccionado!)),
              ],
            ),
    );
  }

  // ---- LISTA DE PACIENTES / CONVERSACIONES ----
  Widget _buildListaConversaciones() {
    return Container(
      width: 280,
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
                _chipAccion(Icons.psychology_outlined, 'Evaluación', () => _enviarPlantilla(p, 'evaluacion'), Colors.orange),
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
        msg = '¡Hola $nombre! 👋\n\nEl Dr. Solís le solicita responder una *evaluación rápida* de su estado de salud bucal.\n\n'
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

  // ---- INFO PACIENTE ----
  void _mostrarInfoPaciente(Paciente p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text('${p.nombre[0]}${p.apellido.isNotEmpty ? p.apellido[0] : ''}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('${p.nombre} ${p.apellido}', style: const TextStyle(fontSize: 15))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow(Icons.phone, 'Teléfono', p.telefono),
            _infoRow(Icons.email_outlined, 'Email', p.email.isNotEmpty ? p.email : 'Sin registro'),
            _infoRow(Icons.location_on_outlined, 'Dirección', p.direccion.isNotEmpty ? p.direccion : 'Sin registro'),
            _infoRow(Icons.cake_outlined, 'Fecha Nac.', p.fechaNacimiento.toString().split(' ').first),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); _mostrarAccionesRapidas(p); },
            icon: const Icon(Icons.send, size: 14),
            label: const Text('Enviar Mensaje'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 13)),
            ],
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
