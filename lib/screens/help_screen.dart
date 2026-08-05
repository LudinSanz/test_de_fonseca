import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _contactarSoporteWhatsApp() async {
    const String tel = '50255551234';
    final String msg = Uri.encodeComponent('Hola Rizo Dental, necesito soporte con la aplicación de evaluación clínica ATM.');
    final Uri waUri = Uri.parse('https://wa.me/$tel?text=$msg');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
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
        title: Row(
          children: [
            Image.asset(
              'assets/images/rizo_logo.png',
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.help_outline,
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
                  'Centro de Ayuda & Soporte Técnico',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // FAQ Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preguntas Frecuentes',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Guía clínica sobre el uso del Test de Fonseca y sincronización con Supabase.',
                      style: TextStyle(fontSize: 13, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 20),

                    _buildFaqItem('¿Cómo funciona la escala del Test de Fonseca?', 'El test evalúa 10 preguntas anamnésicas sumando de 0 a 100 puntos para clasificar la disfunción ATM en: Sin disfunción, Leve, Moderada o Severa.'),
                    _buildFaqItem('¿Los datos se guardan en tiempo real?', 'Sí, cada evaluación, receta, cita o paciente registrado se guarda automáticamente en Supabase.'),
                    _buildFaqItem('¿Cómo exporto una receta o informe a PDF?', 'Al finalizar cualquier evaluación o receta, presiona el botón "Compartir PDF" para generar el documento oficial y enviarlo por WhatsApp.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // WhatsApp Direct Contact Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                      child: const Icon(Icons.headset_mic_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Soporte Técnico Directo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.onSurface)),
                          Text('¿Tienes dudas adicionales? Escríbenos', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _contactarSoporteWhatsApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('WhatsApp'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Center(
                child: Text('Rizo Dental v2.5 • The Clinical Sanctuary', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface))),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(answer, style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
