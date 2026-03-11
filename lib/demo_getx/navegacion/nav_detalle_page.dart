import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// NAVEGACIÓN — Página de detalle
///
/// Get.arguments → recibe los datos enviados desde Get.toNamed()
/// Get.back()    → regresa a la pantalla anterior
class NavDetallePage extends StatelessWidget {
  const NavDetallePage({super.key});

  @override
  Widget build(BuildContext context) {
    // ── Leer argumentos recibidos ────────────────────────────
    final args   = Get.arguments as Map<String, dynamic>;
    final titulo = args['titulo'] as String;
    final hora   = args['hora']   as String;
    final color  = args['color']  as Color;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: const Text('Detalle de tarea'),
        // Get.back() en el botón de retroceso (automático con AppBar)
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Datos recibidos vía Get.arguments ───────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.access_time, color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(hora,
                        style: TextStyle(fontSize: 16, color: color)),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Nota informativa para la presentación
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '💡  Los datos llegaron a través de:\n\n'
                '    Get.toNamed(rutaDetalle, arguments: { ... })\n\n'
                '    y se leen con:\n\n'
                '    final args = Get.arguments;',
                style: TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),

            const Spacer(),

            // ── Get.back() ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Get.back()  →  regresar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Get.back(), // ← regresa a la pagina anterior
              ),
            ),
          ],
        ),
      ),
    );
  }
}
