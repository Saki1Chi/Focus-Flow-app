// ============================================================
//  DEMO GetX — Calendario
//  Para ejecutar SOLO este demo:
//    flutter run -t lib/demo_getx/main_demo.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'aspecto/aspecto_page.dart';
import 'navegacion/nav_rutas.dart';
import 'persistencia/persistencia_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar GetStorage (necesario una sola vez)
  await GetStorage.init();

  runApp(const DemoGetXApp());
}

class DemoGetXApp extends StatelessWidget {
  const DemoGetXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(           // ← GetMaterialApp (no MaterialApp)
      title: 'Demo GetX',
      debugShowCheckedModeBanner: false,
      getPages: navRutas,           // ← rutas nombradas registradas aquí
      home: const DemoHome(),
    );
  }
}

// ── Pantalla principal del demo ──────────────────────────────

class DemoHome extends StatelessWidget {
  const DemoHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Demo GetX — Calendario'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tres conceptos clave de GetX',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Toca cada sección para ver la demo.',
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // ── 1. Aspecto ─────────────────────────────────
            _ConceptoCard(
              numero: '1',
              titulo: 'Aspecto',
              descripcion: 'Estado reactivo',
              codigo: '.obs  +  Obx()',
              icono: Icons.palette_outlined,
              color: Colors.blue,
              onTap: () => Get.to(() => const AspectoPage()),
            ),

            // ── 2. Navegación ──────────────────────────────
            _ConceptoCard(
              numero: '2',
              titulo: 'Navegación',
              descripcion: 'Rutas nombradas',
              codigo: 'Get.toNamed()',
              icono: Icons.navigation_outlined,
              color: Colors.green,
              onTap: () => Get.toNamed(rutaInicio),
            ),

            // ── 3. Persistencia ────────────────────────────
            _ConceptoCard(
              numero: '3',
              titulo: 'Persistencia',
              descripcion: 'Guardar y leer datos',
              codigo: '.write()  +  .read()',
              icono: Icons.save_outlined,
              color: Colors.orange,
              onTap: () => Get.to(() => const PersistenciaPage()),
            ),

            const Spacer(),

            // ── Nota de la carpeta ─────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                'lib/demo_getx/\n'
                '  ├─ aspecto/        (.obs + Obx)\n'
                '  ├─ navegacion/     (Get.toNamed)\n'
                '  └─ persistencia/   (.write + .read)',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget de tarjeta por concepto ───────────────────────────

class _ConceptoCard extends StatelessWidget {
  final String numero, titulo, descripcion, codigo;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  const _ConceptoCard({
    required this.numero,
    required this.titulo,
    required this.descripcion,
    required this.codigo,
    required this.icono,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Número
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(numero,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            const SizedBox(width: 14),

            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(descripcion,
                      style: TextStyle(color: color, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      codigo,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            Icon(icono, color: color, size: 28),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 14),
          ],
        ),
      ),
    );
  }
}
