import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reporte.dart';
import 'package:graphify/graphify.dart';

class ReportsScreen extends StatefulWidget {
  final List<Reporte> reportes;
  const ReportsScreen({Key? key, required this.reportes}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Test de Fonseca'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: widget.reportes.isEmpty
          ? const Center(child: Text('No hay reportes registrados.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: 120,
                    child: _buildBarChart(widget.reportes),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.reportes.length,
                    itemBuilder: (context, index) {
                      final reporte = widget.reportes[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.assignment_turned_in, color: Colors.blue),
                          title: Text('Tipo: ${reporte.tipo}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fecha: ${_formatDate(reporte.fecha)}'),
                              Text('Contenido: ${reporte.contenido.length > 30 ? reporte.contenido.substring(0, 30) + '...' : reporte.contenido}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.share, color: Colors.green),
                            onPressed: () {
                              _exportReport(reporte);
                            },
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

  Widget _buildBarChart(List<Reporte> reportes) {
    final Map<String, int> buckets = {};
    for (var r in reportes) {
      String label = r.tipo;
      buckets[label] = (buckets[label] ?? 0) + 1;
    }
    final tipos = buckets.keys.toList();
    final valores = tipos.map((t) => buckets[t]!).toList();
    final controller = GraphifyController();
    return SizedBox(
      height: 140,
      child: GraphifyView(
        controller: controller,
        initialOptions: {
          "xAxis": {
            "type": "category",
            "data": tipos,
            "axisLabel": {"fontSize": 10}
          },
          "yAxis": {
            "type": "value",
            "axisLabel": {"fontSize": 10}
          },
          "series": [
            {
              "data": valores,
              "type": "bar",
              "itemStyle": {"color": "#1976d2"},
              "barWidth": 18
            }
          ],
          "grid": {"left": 10, "right": 10, "top": 10, "bottom": 30, "containLabel": true},
        },
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year}';
  }

  Future<void> _exportReport(Reporte reporte) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final reporteData = reporte.toMap();
    reporteData['generado_por'] = user?.id ?? '';
    try {
      await supabase.from('reportes').insert(reporteData);
    } catch (e) {
      print('Error al guardar reporte en Supabase: $e');
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Reporte de Test de Fonseca',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('Tipo: ${reporte.tipo}', style: const pw.TextStyle(fontSize: 18)),
            pw.Text('Fecha: ${_formatDate(reporte.fecha)}', style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 24),
            pw.Text('Contenido:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(reporte.contenido, style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 24),
            pw.Text('Este reporte fue generado automáticamente por la app.', style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
