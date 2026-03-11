import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'nav_rutas.dart';

/// NAVEGACIÓN — Página de inicio
///
/// Get.toNamed('/ruta')           → navega a la ruta
/// Get.toNamed('/ruta', arguments: datos) → pasa datos
class NavInicioPage extends StatelessWidget {
  const NavInicioPage({super.key});

  // Tareas de ejemplo (simula el calendario)
  static const _tareas = [
    ('📅  Reunión de equipo',    '10:00 am', Colors.blue),
    ('🏋️  Gym',                  '06:00 am', Colors.green),
    ('📝  Entregar informe',     '03:00 pm', Colors.orange),
    ('💊  Tomar medicamento',    '08:00 pm', Colors.red),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navegación — Get.toNamed()'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Toca una tarea para ver el detalle',
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Lista de tareas
            ...(_tareas.map((t) => _TareaCard(
                  titulo: t.$1,
                  hora: t.$2,
                  color: t.$3,
                  // ── Get.toNamed() con argumentos ────────────
                  onTap: () => Get.toNamed( // GET TO NAMED
                    rutaDetalle, //LA VARIABLE
                    arguments: { // ARGUMENTOS
                      'titulo': t.$1,
                      'hora':   t.$2,
                      'color':  t.$3,
                    },
                  ),
                ))),
          ],
        ),
      ),
    );
  }
}

class _TareaCard extends StatelessWidget {
  final String titulo, hora;
  final Color color;
  final VoidCallback onTap;

  const _TareaCard({
    required this.titulo,
    required this.hora,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(Icons.event, color: color),
        ),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(hora),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
