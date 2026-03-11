import 'package:get/get.dart';
import 'nav_inicio_page.dart';
import 'nav_detalle_page.dart';

/// NAVEGACIÓN — Rutas nombradas de GetX
///
/// Se pasan a GetMaterialApp(getPages: navRutas).
/// Luego se llaman con Get.toNamed('/ruta').
const String rutaInicio = '/nav-inicio';
const String rutaDetalle = '/nav-detalle';

final navRutas = [
  GetPage(name: rutaInicio, page: () => const NavInicioPage()),
  GetPage(name: rutaDetalle, page: () => const NavDetallePage()),
];
