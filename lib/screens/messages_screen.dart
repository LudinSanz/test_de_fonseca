import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _msgController = TextEditingController();

  final List<Map<String, dynamic>> _botMessages = [
    {
      'sender': 'bot',
      'text': '¡Hola! Bienvenido a Rizo Dental Sanctuary (+502 5981-6632). 🦷✨\n\n¿En qué podemos ayudarte hoy?\n\n1: Confirmar Cita\n2: Reprogramar Cita\n3: Cancelar Cita\n4: Indicaciones Postoperatorias',
      'time': '10:00 AM',
    },
  ];

  final List<Map<String, dynamic>> _recordatorios = [
    {
      'titulo': 'Prescripción Médica: Ibuprofeno 600mg',
      'subtitulo': 'Tomar 1 tableta cada 8 horas tras alimentos',
      'hora': '08:00 PM',
      'estado': 'Pendiente',
      'icono': Icons.medication_outlined,
      'color': AppColors.primary,
    },
    {
      'titulo': 'Ayuno Preoperatorio (Terceros Molares)',
      'subtitulo': 'Iniciar ayuno de líquidos y sólidos 8 horas antes de la cita',
      'hora': 'Mañana 07:00 AM',
      'estado': 'Importante',
      'icono': Icons.warning_amber_rounded,
      'color': AppColors.warning,
    },
    {
      'titulo': 'Uso Nocturno de Férula Miorrelajante',
      'subtitulo': 'Colocar férula tipo Michigan antes de dormir para control de bruxismo ATM',
      'hora': '10:00 PM',
      'estado': 'Programado',
      'icono': Icons.nightlight_round_outlined,
      'color': AppColors.info,
    },
  ];

  final List<Map<String, dynamic>> _recepcionMessages = [
    {
      'sender': 'recepcion',
      'text': '🔴 *Atención con Recepción Rizo Dental*\nUn asistente humano está atendiendo tu consulta directamente en recepción.',
      'time': '10:05 AM',
    },
    {
      'sender': 'paciente',
      'text': 'Hola, quisiera cotizar la férula miorrelajante y el test de evaluación ATM.',
      'time': '10:06 AM',
    },
    {
      'sender': 'recepcion',
      'text': '¡Con gusto! El paquete de evaluación ATM con Test de Fonseca tiene un costo de Q 350.00 y la férula miorrelajante Q 1,500.00 en Quetzales. ¿Deseas agendar para esta semana?',
      'time': '10:07 AM',
    }
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _enviarComandoBot(String texto) {
    setState(() {
      _botMessages.add({
        'sender': 'user',
        'text': texto,
        'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      });
    });

    String respuesta = '';
    final lower = texto.toLowerCase();
    if (lower.contains('1') || lower.contains('confirmar')) {
      respuesta = '✅ *CITA CONFIRMADA EXITOSAMENTE*\nGracias por confirmar tu asistencia a Rizo Dental. Te esperamos en Sixtino II, Zona 10.';
    } else if (lower.contains('2') || lower.contains('reprogramar')) {
      respuesta = '🔄 *SOLICITUD DE REPROGRAMACIÓN*\nUn asistente de recepción se comunicará a tu WhatsApp (+502 5981-6632) para seleccionar tu nueva fecha.';
    } else if (lower.contains('3') || lower.contains('cancelar')) {
      respuesta = '❌ *CITA CANCELADA*\nTu cita fue cancelada. Puedes volver a agendar en cualquier momento por este medio o WhatsApp.';
    } else if (lower.contains('cita')) {
      respuesta = '📅 Tu próxima cita registrada en Rizo Dental está activa. Puedes ver el detalle en la pestaña Citas.';
    } else {
      respuesta = '🤖 *ASISTENTE RIZO DENTAL*\nRecibimos tu mensaje. Para atención personalizada directa por WhatsApp, presiona el botón inferior o selecciona la pestaña "Atención con Recepción".';
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _botMessages.add({
            'sender': 'bot',
            'text': respuesta,
            'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          });
        });
      }
    });
  }

  void _abrirWhatsAppDirecto() async {
    const phone = '+50259816632';
    final url = Uri.parse('https://wa.me/50259816632?text=${Uri.encodeComponent("Hola Rizo Dental, necesito asistencia personalizada para mi cita/tratamiento.")}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
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
                Icons.chat_bubble_outline_rounded,
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
                  'Módulo de Mensajes • WhatsApp +502 5981-6632',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_outlined, color: AppColors.primary),
            onPressed: _abrirWhatsAppDirecto,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          tabs: const [
            Tab(icon: Icon(Icons.smart_toy_outlined, size: 18), text: 'Bot WhatsApp'),
            Tab(icon: Icon(Icons.notifications_active_outlined, size: 18), text: 'Recordatorios'),
            Tab(icon: Icon(Icons.support_agent_outlined, size: 18), text: 'Recepción'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBotWhatsAppTab(),
            _buildRecordatoriosTab(),
            _buildRecepcionTab(),
          ],
        ),
      ),
    );
  }

  // TAB 1: BOT DE LA CLINICA (WHATSAPP +502 5981-6632)
  Widget _buildBotWhatsAppTab() {
    return Column(
      children: [
        // Quick Action Command Pills
        Container(
          height: 46,
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildActionPill('📅 Ver mi próxima cita', () => _enviarComandoBot('Ver mi próxima cita')),
              _buildActionPill('🩺 Indicaciones postoperatorias', () => _enviarComandoBot('4: Indicaciones Postoperatorias')),
              _buildActionPill('✅ Confirmar cita', () => _enviarComandoBot('1: Confirmar Cita')),
              _buildActionPill('🔄 Reprogramar', () => _enviarComandoBot('2: Reprogramar Cita')),
            ],
          ),
        ),

        // Chat List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _botMessages.length,
            itemBuilder: (context, index) {
              final msg = _botMessages[index];
              final isBot = msg['sender'] == 'bot';
              return Align(
                alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  decoration: BoxDecoration(
                    color: isBot ? AppColors.surfaceContainerLowest : AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isBot ? 4 : 18),
                      bottomRight: Radius.circular(isBot ? 18 : 4),
                    ),
                    boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg['text'],
                        style: TextStyle(
                          color: isBot ? AppColors.onSurface : Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          msg['time'],
                          style: TextStyle(
                            fontSize: 9,
                            color: isBot ? AppColors.textLight : Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Input bar
        _buildInputBar((text) {
          if (text.trim().isNotEmpty) {
            _enviarComandoBot(text.trim());
          }
        }),
      ],
    );
  }

  // TAB 2: RECORDATORIOS E INDICACIONES AUTOMATICAS
  Widget _buildRecordatoriosTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: _recordatorios.length,
      itemBuilder: (context, index) {
        final rec = _recordatorios[index];
        final Color col = rec['color'] as Color;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: col.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(rec['icono'] as IconData, color: col, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rec['titulo'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface)),
                    const SizedBox(height: 3),
                    Text(rec['subtitulo'], style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(rec['hora'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: Text(rec['estado'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 3: ATENCION CON RECEPCION HUMANA (+502 5981-6632)
  Widget _buildRecepcionTab() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: AppColors.warning.withOpacity(0.12),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: Colors.red, size: 10),
              SizedBox(width: 8),
              Text(
                '🔴 Consulta pendiente de atención humana en Recepción',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _recepcionMessages.length,
            itemBuilder: (context, index) {
              final msg = _recepcionMessages[index];
              final isRecepcion = msg['sender'] == 'recepcion';
              return Align(
                alignment: isRecepcion ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  decoration: BoxDecoration(
                    color: isRecepcion ? AppColors.surfaceContainerLowest : AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg['text'],
                        style: TextStyle(
                          color: isRecepcion ? AppColors.onSurface : Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          msg['time'],
                          style: TextStyle(
                            fontSize: 9,
                            color: isRecepcion ? AppColors.textLight : Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildInputBar((text) {
          if (text.trim().isNotEmpty) {
            setState(() {
              _recepcionMessages.add({
                'sender': 'paciente',
                'text': text.trim(),
                'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              });
            });
          }
        }),
      ],
    );
  }

  Widget _buildActionPill(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.ghostOutline, width: 1),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(Function(String) onSend) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.ghostOutline, width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: 'Escribe tu mensaje a Rizo Dental...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: () {
                final txt = _msgController.text;
                _msgController.clear();
                onSend(txt);
              },
            ),
          ),
        ],
      ),
    );
  }
}
