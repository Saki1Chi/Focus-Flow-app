import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'aspecto_controller.dart';

/// ASPECTO — Uso de Obx()
///
/// Obx(() => Widget)  →  se reconstruye SOLO cuando
/// alguna variable .obs que usa dentro cambia su valor.
/// No necesita setState() ni notifyListeners().
class AspectoPage extends StatelessWidget {
  const AspectoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get.put() crea e inyecta el controlador
    final ctrl = Get.put(AspectoController());

    // Obx externo → toda la página reacciona al cambio de modo
    return Obx(() => Scaffold(
          backgroundColor:
              ctrl.modoOscuro.value ? const Color(0xFF1A1A2E) : Colors.white,
          appBar: AppBar(
            backgroundColor: ctrl.colorAccent.value,
            title: const Text(
              'Aspecto — .obs + Obx()',
              style: TextStyle(color: Colors.white),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Vista previa reactiva ───────────────────
                _seccion('Vista previa (reacciona al instante)', ctrl),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ctrl.colorAccent.value.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ctrl.colorAccent.value, width: 2),
                  ),
                  child: Text(
                    '📅  Reunión de equipo — 10:00 am',
                    style: TextStyle(
                      fontSize: ctrl.tamanioTexto.value,
                      fontWeight: FontWeight.w500,
                      color: ctrl.modoOscuro.value
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Toggle modo oscuro ──────────────────────
                _seccion('Modo oscuro', ctrl),
                Row(
                  children: [
                    Switch(
                      value: ctrl.modoOscuro.value,
                      activeThumbColor: ctrl.colorAccent.value,
                      onChanged: (_) => ctrl.toggleModo(), // modifica .obs
                    ),
                    Text(
                      ctrl.modoOscuro.value ? 'Oscuro' : 'Claro',
                      style: TextStyle(
                        color: ctrl.modoOscuro.value
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Selector de color ───────────────────────
                _seccion('Color acento', ctrl),
                const SizedBox(height: 10),
                Row(
                  children: ctrl.colores.entries.map((e) {
                    final seleccionado = ctrl.colorAccent.value == e.value;
                    return GestureDetector(
                      onTap: () => ctrl.cambiarColor(e.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        width: seleccionado ? 44 : 36,
                        height: seleccionado ? 44 : 36,
                        decoration: BoxDecoration(
                          color: e.value,
                          shape: BoxShape.circle,
                          border: seleccionado
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: e.value.withValues(alpha: 0.5),
                              blurRadius: seleccionado ? 8 : 2,
                            ),
                          ],
                        ),
                        child: seleccionado
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // ── Tamaño de fuente ────────────────────────
                _seccion(
                    'Tamaño de fuente: ${ctrl.tamanioTexto.value.toInt()}sp',
                    ctrl),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: ctrl.colorAccent.value,
                      iconSize: 30,
                      onPressed: ctrl.disminuirFuente,
                    ),
                    Text(
                      '${ctrl.tamanioTexto.value.toInt()}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ctrl.modoOscuro.value
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: ctrl.colorAccent.value,
                      iconSize: 30,
                      onPressed: ctrl.aumentarFuente,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
  }

  Widget _seccion(String titulo, AspectoController ctrl) => Text(
        titulo,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: ctrl.modoOscuro.value ? Colors.white60 : Colors.black45,
        ),
      );
}
