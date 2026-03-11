import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// PERSISTENCIA — GetStorage (.write / .read)
///
/// GetStorage guarda datos en disco (key-value).
/// Persisten aunque cierres la app o hagas hot restart.
class PersistenciaController extends GetxController {
  // Caja de almacenamiento (como SharedPreferences pero más rápido)
  final _box = GetStorage();

  // Claves de almacenamiento
  static const _keyNombre = 'p_nombre';
  static const _keyNota   = 'p_nota';
  static const _keyTareas = 'p_tareas';

  // Estado reactivo (.obs) — sincronizado con el disco
  var nombre = ''.obs;
  var nota   = ''.obs;
  var tareas = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    // ── .read() al iniciar → carga lo que ya estaba guardado ──
    nombre.value = _box.read(_keyNombre) ?? '';
    nota.value   = _box.read(_keyNota)   ?? '';
    tareas.value = List<String>.from(_box.read(_keyTareas) ?? []);
  }

  // ── Guardar nombre ─────────────────────────────────────────
  void guardarNombre(String valor) {
    nombre.value = valor;
    _box.write(_keyNombre, valor); // ← .write()
  }

  // ── Guardar nota ───────────────────────────────────────────
  void guardarNota(String valor) {
    nota.value = valor;
    _box.write(_keyNota, valor);   // ← .write()
  }

  // ── Agregar tarea a la lista ───────────────────────────────
  void agregarTarea(String tarea) {
    if (tarea.isEmpty) return;
    tareas.add(tarea);
    _box.write(_keyTareas, tareas.toList()); // ← .write()
  }

  // ── Borrar todo ────────────────────────────────────────────
  void borrarTodo() {
    nombre.value = '';
    nota.value   = '';
    tareas.clear();
    _box.erase(); // borra todas las claves
  }
}
