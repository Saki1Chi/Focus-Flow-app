import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// ASPECTO — Estado reactivo con GetX
///
/// Cada variable termina en .obs → se vuelve "observable".
/// Cuando cambia su valor, todos los Obx() que la usan
/// se reconstruyen automáticamente.
class AspectoController extends GetxController {
  // ── Variables observables (.obs) ──────────────────────────
  var modoOscuro = false.obs;                          // Rx<bool>
  var colorAccent = const Color(0xFF2196F3).obs;       // Rx<Color>
  var tamanioTexto = 16.0.obs;                         // Rx<double>

  // Paleta de colores disponibles
  final colores = const <String, Color>{
    'Azul':    Color(0xFF2196F3),
    'Verde':   Color(0xFF4CAF50),
    'Rojo':    Color(0xFFF44336),
    'Naranja': Color(0xFFFF9800),
    'Morado':  Color(0xFF9C27B0),
  };

  // ── Métodos que modifican el estado ───────────────────────
  void toggleModo() => modoOscuro.toggle();

  void cambiarColor(Color c) => colorAccent.value = c;

  void aumentarFuente() => tamanioTexto.value += 2;

  void disminuirFuente() {
    if (tamanioTexto.value > 10) tamanioTexto.value -= 2;
  }
}
