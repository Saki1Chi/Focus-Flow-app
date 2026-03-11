import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'persistencia_controller.dart';

/// PERSISTENCIA — Uso de .write() y .read()
///
/// Guarda datos con _box.write(clave, valor)
/// Lee datos con   _box.read(clave)
///
/// → Los datos sobreviven al hot restart y al cierre de la app.
class PersistenciaPage extends StatelessWidget {
  const PersistenciaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl         = Get.put(PersistenciaController());
    final nombreCtrl   = TextEditingController(text: ctrl.nombre.value);
    final notaCtrl     = TextEditingController(text: ctrl.nota.value);
    final tareaCtrl    = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Persistencia — .write() + .read()'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Borrar todo',
            onPressed: () {
              ctrl.borrarTodo();
              nombreCtrl.clear();
              notaCtrl.clear();
              tareaCtrl.clear();
            },
          ),
        ],
      ),
      body: Obx(() => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Info: persiste entre sesiones ─────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Haz hot restart y los datos siguen ahí.\n'
                          'Eso es GetStorage en acción.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Campo: Nombre ──────────────────────────────
                _Titulo('Nombre del usuario'),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: nombreCtrl,
                      decoration: _deco('Tu nombre', Icons.person),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BotonGuardar(
                    color: Colors.orange,
                    onPressed: () => ctrl.guardarNombre(nombreCtrl.text),
                  ),
                ]),
                if (ctrl.nombre.value.isNotEmpty)
                  _Leido('nombre', ctrl.nombre.value),  // ← .read()

                const SizedBox(height: 20),

                // ── Campo: Nota ────────────────────────────────
                _Titulo('Nota rápida'),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: notaCtrl,
                      decoration: _deco('Escribe algo...', Icons.note),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BotonGuardar(
                    color: Colors.orange,
                    onPressed: () => ctrl.guardarNota(notaCtrl.text),
                  ),
                ]),
                if (ctrl.nota.value.isNotEmpty)
                  _Leido('nota', ctrl.nota.value),

                const SizedBox(height: 20),

                // ── Lista de tareas ────────────────────────────
                _Titulo('Tareas del calendario (lista)'),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: tareaCtrl,
                      decoration:
                          _deco('Ej: Reunión a las 10am', Icons.event),
                      onSubmitted: (v) {
                        ctrl.agregarTarea(v);
                        tareaCtrl.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BotonGuardar(
                    color: Colors.orange,
                    icon: Icons.add,
                    onPressed: () {
                      ctrl.agregarTarea(tareaCtrl.text);
                      tareaCtrl.clear();
                    },
                  ),
                ]),

                const SizedBox(height: 8),

                // ── Tareas guardadas (.read()) ─────────────────
                if (ctrl.tareas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sin tareas guardadas aún.',
                        style: TextStyle(color: Colors.black38)),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '← leídas con  _box.read("p_tareas")',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 6),
                      ...ctrl.tareas.asMap().entries.map((e) => Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    Colors.orange.withValues(alpha: 0.15),
                                child: Text('${e.key + 1}',
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                              title: Text(e.value),
                              trailing: Icon(Icons.check_circle_outline,
                                  color: Colors.orange.shade300),
                            ),
                          )),
                    ],
                  ),
              ],
            ),
          )),
    );
  }

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.orange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

// ── Widgets auxiliares ───────────────────────────────────────

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black54)),
      );
}

/// Muestra el valor que fue leído con .read()
class _Leido extends StatelessWidget {
  final String clave, valor;
  const _Leido(this.clave, this.valor);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '← _box.read("p_$clave") = "$valor"',
          style: const TextStyle(
              fontSize: 12,
              color: Colors.orange,
              fontFamily: 'monospace'),
        ),
      );
}

class _BotonGuardar extends StatelessWidget {
  final VoidCallback onPressed;
  final Color color;
  final IconData icon;
  const _BotonGuardar({
    required this.onPressed,
    required this.color,
    this.icon = Icons.save,
  });
  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(50, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Icon(icon),
      );
}
