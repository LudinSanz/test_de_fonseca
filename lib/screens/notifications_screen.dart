import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'appointments_screen.dart';
import 'patient_directory_screen.dart';
import 'treatments_screen.dart';
import 'inventory_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Configuración de notificaciones activas
  bool _notificacionesPush = true;
  bool _recordatoriosWhatsApp = true;
  bool _alertasInventario = true;
  bool _alertasATM = true;

  // Lista viva de notificaciones clínicas
  final List<Map<String, dynamic>> _notificaciones = [
    {
      'id': 'notif_1',
      'tipo': 'cita',
      'titulo': 'Próxima Cita Programada',
      'mensaje': 'Hoy a las 15:00 hrs: Consulta y evaluación con el paciente Juan Pérez.',
      'hora': 'Hace 10 min',
      'leido': false,
      'icono': Icons.calendar_month_outlined,
      'color': Color(0xFF983C00),
    },
    {
      'id': 'notif_2',
      'tipo': 'atm',
      'titulo': 'Test de Fonseca Reciente',
      'mensaje': 'Paciente con puntaje de 48 pts (Disfunción ATM Moderada) requiere revisión.',
      'hora': 'Hace 45 min',
      'leido': false,
      'icono': Icons.assessment_outlined,
      'color': AppColors.primary,
    },
    {
      'id': 'notif_3',
      'tipo': 'tratamiento',
      'titulo': 'Seguimiento de Tratamiento Activo',
      'mensaje': 'María López cumple 48 hrs post-procedimiento de Lipopada de papada.',
      'hora': 'Hace 2 horas',
      'leido': false,
      'icono': Icons.medical_services_outlined,
      'color': Color(0xFF007A78),
    },
    {
      'id': 'notif_4',
      'tipo': 'inventario',
      'titulo': 'Alerta de Inventario Clínico',
      'mensaje': 'Existencias bajas en Anestesia Mepivacaína 2% (quedan 8 unidades).',
      'hora': 'Ayer',
      'leido': true,
      'icono': Icons.inventory_2_outlined,
      'color': Color(0xFF6A0DAD),
    },
    {
      'id': 'notif_5',
      'tipo': 'whatsapp',
      'titulo': 'Mensajes y Recordatorios WhatsApp',
      'mensaje': 'Recordatorio de cita enviado exitosamente a 4 pacientes de la clínica.',
      'hora': 'Ayer',
      'leido': true,
      'icono': Icons.chat_outlined,
      'color': Color(0xFF25D366),
    },
  ];

  int get _conteoNoLeidos => _notificaciones.where((n) => n['leido'] == false).length;

  void _marcarTodasLeidas() {
    setState(() {
      for (var n in _notificaciones) {
        n['leido'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todas las alertas marcadas como leídas'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _abrirModulo(String tipo) {
    switch (tipo) {
      case 'cita':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsScreen()));
        break;
      case 'atm':
      case 'paciente':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientDirectoryScreen()));
        break;
      case 'tratamiento':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TreatmentsScreen()));
        break;
      case 'inventario':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
        break;
    }
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Centro de Notificaciones',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            Text(
              'Alertas clínicas y recordatorios activos',
              style: TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
        actions: [
          if (_conteoNoLeidos > 0)
            TextButton(
              onPressed: _marcarTodasLeidas,
              child: const Text('Leídas', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // ── TARJETA DE ESTADO: NOTIFICACIONES EN VIVO ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 18, offset: Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notificaciones Activas en la App',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _notificacionesPush
                              ? 'Alertas en tiempo real de citas, ATM y tratamientos activas.'
                              : 'Notificaciones en pausa.',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _notificacionesPush,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.white38,
                    onChanged: (val) {
                      setState(() => _notificacionesPush = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Notificaciones activadas exitosamente' : 'Notificaciones desactivadas'),
                          backgroundColor: val ? AppColors.success : AppColors.warning,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── SECCIÓN CONFIGURACIÓN RÁPIDA DE ALERTAS ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 12, offset: Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CANALES Y ALERTAS CLÍNICAS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),
                  _buildToggleRow(
                    'Recordatorios automáticos por WhatsApp',
                    'Envío de confirmación de citas con +502 5981-6632',
                    _recordatoriosWhatsApp,
                    (v) => setState(() => _recordatoriosWhatsApp = v),
                    Icons.chat_outlined,
                  ),
                  const Divider(height: 14, color: AppColors.ghostOutline),
                  _buildToggleRow(
                    'Alertas de Test de Fonseca & ATM',
                    'Avisos de pacientes con sospecha de disfunción moderada/severa',
                    _alertasATM,
                    (v) => setState(() => _alertasATM = v),
                    Icons.health_and_safety_outlined,
                  ),
                  const Divider(height: 14, color: AppColors.ghostOutline),
                  _buildToggleRow(
                    'Alertas de Stock en Inventario',
                    'Avisos inmediatos cuando insumos lleguen al stock mínimo',
                    _alertasInventario,
                    (v) => setState(() => _alertasInventario = v),
                    Icons.inventory_2_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── LISTA DE ALERTAS RECIENTES ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Alertas y Recordatorios Recientes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                if (_conteoNoLeidos > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_conteoNoLeidos nueva${_conteoNoLeidos != 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Lista de Tarjetas
            ..._notificaciones.map((notif) {
              final isLeido = notif['leido'] as bool;
              final Color color = notif['color'] as Color;

              return InkWell(
                onTap: () {
                  setState(() => notif['leido'] = true);
                  _abrirModulo(notif['tipo'] as String);
                },
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isLeido ? AppColors.surfaceContainerLowest : color.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isLeido ? AppColors.ghostOutline : color.withOpacity(0.4),
                      width: isLeido ? 1.0 : 1.3,
                    ),
                    boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 10, offset: Offset(0, 3))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(notif['icono'] as IconData, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notif['titulo'] as String,
                                    style: TextStyle(
                                      fontWeight: isLeido ? FontWeight.w600 : FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                                if (!isLeido)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif['mensaje'] as String,
                              style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.35),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  notif['hora'] as String,
                                  style: const TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w500),
                                ),
                                Row(
                                  children: [
                                    Text('Ver detalle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                                    const SizedBox(width: 2),
                                    Icon(Icons.chevron_right, size: 14, color: color),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    String titulo,
    String subtitulo,
    bool valor,
    ValueChanged<bool> onChanged,
    IconData icono,
  ) {
    return Row(
      children: [
        Icon(icono, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.onSurface)),
              Text(subtitulo, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
            ],
          ),
        ),
        Switch(
          value: valor,
          activeColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
