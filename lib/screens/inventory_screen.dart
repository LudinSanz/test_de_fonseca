import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  String _selectedCategory = 'Todos';

  @override
  void initState() {
    super.initState();
    _cargarInventario();
  }

  Future<void> _cargarInventario() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('inventario')
          .select()
          .order('nombre', ascending: true);

      setState(() {
        _items = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error al cargar inventario: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirModalAgregarEditar({Map<String, dynamic>? item}) {
    final nombreController = TextEditingController(text: item?['nombre'] ?? '');
    final categoriaController = TextEditingController(text: item?['categoria'] ?? 'Medicamentos');
    final cantidadController = TextEditingController(text: item?['cantidad']?.toString() ?? '10');
    final unidadController = TextEditingController(text: item?['unidad'] ?? 'unidades');
    final minController = TextEditingController(text: item?['stock_minimo']?.toString() ?? '5');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          item == null ? 'Nuevo Ítem de Inventario' : 'Editar Ítem',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreController, decoration: _inputDecoration('Nombre del artículo / medicamento')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: ['Medicamentos', 'Instrumental', 'Insumos / Materiales'].contains(categoriaController.text)
                    ? categoriaController.text
                    : 'Medicamentos',
                decoration: _inputDecoration('Categoría'),
                dropdownColor: AppColors.surfaceContainerLowest,
                items: const [
                  DropdownMenuItem(value: 'Medicamentos', child: Text('Medicamentos')),
                  DropdownMenuItem(value: 'Instrumental', child: Text('Instrumental Odontológico')),
                  DropdownMenuItem(value: 'Insumos / Materiales', child: Text('Insumos / Materiales')),
                ],
                onChanged: (val) {
                  if (val != null) categoriaController.text = val;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: cantidadController, keyboardType: TextInputType.number, decoration: _inputDecoration('Cantidad'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: unidadController, decoration: _inputDecoration('Unidad (ej: cajas)'))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: minController, keyboardType: TextInputType.number, decoration: _inputDecoration('Stock Mínimo de Alerta')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.trim().isNotEmpty) {
                final id = item?['id'] ?? 'inv_${DateTime.now().millisecondsSinceEpoch}';
                final itemData = {
                  'id': id,
                  'nombre': nombreController.text.trim(),
                  'categoria': categoriaController.text.trim(),
                  'cantidad': int.tryParse(cantidadController.text.trim()) ?? 0,
                  'unidad': unidadController.text.trim(),
                  'stock_minimo': int.tryParse(minController.text.trim()) ?? 5,
                };

                try {
                  final supabase = Supabase.instance.client;
                  await supabase.from('inventario').upsert(itemData);
                  Navigator.pop(ctx);
                  _cargarInventario();
                } catch (e) {
                  debugPrint('Error al guardar en inventario: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Guardar en Supabase'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline, width: 1.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _selectedCategory == 'Todos'
        ? _items
        : _items.where((i) => i['categoria'] == _selectedCategory).toList();

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
                Icons.inventory_2_outlined,
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
                  'Control de Inventario Clínico',
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
            icon: const Icon(Icons.add, color: AppColors.primary, size: 28),
            onPressed: () => _abrirModalAgregarEditar(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Filter Chips
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['Todos', 'Medicamentos', 'Instrumental', 'Insumos / Materiales'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceContainerLowest,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // Inventory Item Cards List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
                                child: const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primary),
                              ),
                              const SizedBox(height: 16),
                              const Text('No hay insumos registrados en inventario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: const Text('Agregar Insumo o Medicamento'),
                                onPressed: () => _abrirModalAgregarEditar(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final int cantidad = item['cantidad'] ?? 0;
                            final int minStock = item['stock_minimo'] ?? 5;
                            final bool lowStock = cantidad <= minStock;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (lowStock ? AppColors.error : AppColors.primary).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      lowStock ? Icons.warning_amber_rounded : Icons.inventory_2,
                                      color: lowStock ? AppColors.error : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.onSurface)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item['categoria']} • $cantidad ${item['unidad'] ?? "unidades"}',
                                          style: TextStyle(fontSize: 12, color: lowStock ? AppColors.error : AppColors.textLight, fontWeight: lowStock ? FontWeight.bold : FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                                    onPressed: () => _abrirModalAgregarEditar(item: item),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
