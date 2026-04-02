# FocusFlow - Sistema de Productividad Multiplataforma

Ecosistema de productividad compuesto por tres componentes integrados:

| Componente | Plataforma | Tecnologia |
|---|---|---|
| **App movil** | Android | Flutter + Dart |
| **Dashboard CMS** | Web / Backend | FastAPI + Python |
| **FocusGuard** | Windows Desktop | Python + Tkinter |

---

## Estructura del repositorio

```
Focus-Flow-app/
├── lib/                        # App Flutter (Android)
│   ├── core/                   # Tema y constantes
│   ├── data/                   # Modelos y repositorios locales
│   ├── presentation/           # Pantallas, providers, widgets
│   └── services/               # API, alarmas, bloqueo de apps
├── backend/                    # CMS FastAPI (Dashboard web)
│   ├── main.py
│   ├── routers/
│   └── static/index.html       # Panel de administracion
├── focusguard/                 # Bloqueador de apps Windows (nuevo)
│   ├── main.py
│   ├── src/                    # Modulos: blocker, ui, config, etc.
│   └── data/                   # Persistencia JSON local
├── android/
├── pubspec.yaml
└── README.md
```

---

## Cambios de apariencia (UI)

### App movil Flutter

Se implemento un sistema de diseno propio llamado **MinimalTheme** basado en Material 3:

**Tokens de diseno** (`lib/core/theme/app_theme.dart`)

| Token | Light | Dark |
|---|---|---|
| Fondo | `#F3F4FF` | `#06060F` |
| Superficie | `#FFFFFF` | `#0C0C1A` |
| Tarjetas | `#FFFFFF` | `#0E0E1C` |
| Texto principal | `#080818` | `#F0F0FF` |
| Texto secundario | `#9898B8` | `#484862` |
| Borde | `rgba(0,0,0,0.05)` | `rgba(255,255,255,0.06)` |

**Tipografia:** Plus Jakarta Sans via `google_fonts` (w700 titulos, w500 cuerpo).

**Efectos visuales** (`NeonColors` en `app_theme.dart`):

- `glow(color)` — brillo neon en dos capas (32% + 12% de opacidad)
- `softGlow(color)` — sombra suave de 22%
- `crystalCard()` — efecto glass: sombra blanca interna + profunda negra
- `lightCard()` — sombra multicapa para modo claro

**Colores de acento seleccionables por el usuario:** Azul, verde, violeta, naranja, rosa — persistidos en `settings_provider`.

**Componentes rediseñados:**
- Cards sin elevacion, bordes de 1 px, radio 18 px
- AppBar plana (sin sombra al hacer scroll)
- Inputs con borde activo en color de acento (1.5 px)
- Botones sin elevacion, padding generoso, texto w700
- `TaskCard` — indicador lateral de estado + efecto glow en acento

---

### Dashboard web (`backend/static/index.html`)

Panel de administracion accesible en `http://localhost:8000/admin`.

**Paleta del dashboard:**

| Variable CSS | Valor | Uso |
|---|---|---|
| `--accent` | `#4A90E2` | Links activos, iconos |
| `--bg` | `#06060F` | Fondo global (mismo que dark de Flutter) |
| `--card` | `#0E0E1C` | Tarjetas y sidebar |
| `--border` | `rgba(255,255,255,0.07)` | Divisores |

**Estructura visual:**
- Sidebar fija de 230 px con navegacion por secciones
- Stat cards con metricas grandes (total, pendiente, en progreso, completado, categorias)
- Tablas de gestion de tareas/categorias con hover sutil
- Badges de estado con colores semanticos (pendiente/en progreso/completada)
- Indicador de conexion en tiempo real (punto verde animado al detectar el backend)

---

## Conexion App Movil — Dashboard

### Flujo de datos

```
Flutter (Hive local)
       |
       |  HTTP JSON
       v
FastAPI backend  ------>  SQLite (focusflow.db)
       |
       v
Dashboard web (/admin)
```

### Configuracion de URL (`lib/core/constants/app_constants.dart`)

```dart
// Emulador Android -> alias de localhost del host
static const String apiBaseUrl = 'http://10.0.2.2:8000';

// Dispositivo fisico -> IP local de la PC en la misma red Wi-Fi
// static const String apiBaseUrl = 'http://192.168.x.x:8000';
```

### Endpoints utilizados por la app

| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| `GET` | `/api/tasks/` | Descarga tareas al iniciar la app |
| `POST` | `/api/tasks/bulk` | Sube todas las tareas locales (upsert) |
| `GET` | `/api/categories/` | Carga categorias disponibles |
| `GET` | `/api/stats` | (Dashboard) Totales por estado |

### Ciclo de sincronizacion (`lib/presentation/providers/task_provider.dart`)

1. Al iniciar: `_pullFromServer()` descarga tareas remotas y reprograma alarmas.
2. En cada CRUD: escribe en Hive primero (offline-first), luego sincroniza al servidor.
3. `syncWithServer()` hace `POST /api/tasks/bulk` con todas las tareas locales.

### Conversion de datos (`lib/services/api_service.dart`)

La app convierte automaticamente entre esquemas:

| Flutter (camelCase) | Python/JSON (snake_case) |
|---|---|
| `startTime` | `start_time` |
| `categoryId` | `category_id` |
| `isCarriedOver` | `is_carried_over` |
| `dayOrder` | `day_order` |

---

## FocusGuard — Bloqueador de apps Windows

**Ubicacion en el repo:** `focusguard/`

Aplicacion de escritorio Windows que bloquea apps distractoras y gestiona sesiones de enfoque
mediante un sistema de incentivos: completa bloques de trabajo para ganar tiempo de desbloqueo.

### Caracteristicas principales

| Funcion | Detalle |
|---|---|
| **Bloqueo de procesos** | Mata procesos `.exe` configurados cada 3 s (psutil) |
| **Sesiones de enfoque** | Completa N bloques de trabajo para desbloquear apps por tiempo limitado |
| **Ventana de desbloqueo** | Configurable: duracion y cantidad de sesiones requeridas |
| **Desbloqueo por hora** | A partir de `unlock_hour` (default 21:00), el bloqueo cesa automaticamente |
| **Racha de productividad** | Dias consecutivos con sesiones completadas |
| **Reset diario** | Contadores se reinician automaticamente al cambiar de dia |
| **Autostart** | Se registra en el Programador de Tareas de Windows |
| **Bandeja del sistema** | Minimiza a tray con menu contextual e indicador de estado |

### Estructura de `focusguard/`

```
focusguard/
├── main.py           # Elevacion UAC, autostart, loop principal
├── requirements.txt  # psutil, plyer, tkcalendar
├── run.bat           # Lanzador sin consola (pythonw)
└── src/
    ├── config.py     # Singleton thread-safe, config JSON, reset diario
    ├── models.py     # Dataclasses: Task, RecurrenceRule, BlockSession
    ├── repository.py # Persistencia JSON: tasks.json, sessions.json
    ├── blocker.py    # BlockerThread: daemon que mata procesos bloqueados
    ├── scheduler.py  # Generacion de tareas recurrentes
    ├── ui.py         # MainWindow: 4 pestanas (Inicio, Calendario, Smart, Ajustes)
    ├── widgets.py    # AnimatedBar, PulsingDot, CheckBox, helpers de tema
    └── tray.py       # Icono de bandeja + notificaciones de escritorio
```

### UI de FocusGuard

- **Temas:** Claro / Oscuro con cambio en tiempo real
- **Colores de acento:** Azul / Rojo / Verde (coherentes con la app movil)
- **Widgets personalizados:**
  - `AnimatedBar` — barra de progreso con interpolacion de color
  - `PulsingDot` — indicador pulsante de sesion activa
  - `CheckBox` — casilla con estilo coherente al tema

### Configuracion por defecto (`focusguard/data/config.json`)

```json
{
  "blocked_apps": ["LeagueClient.exe", "VALORANT-Win64-Shipping.exe"],
  "unlock_hour": 21,
  "unlock_duration_minutes": 20,
  "blocks_to_unlock": 3,
  "dark_mode": false,
  "accent_color": "blue"
}
```

### Instalacion de FocusGuard

```bash
cd focusguard
pip install -r requirements.txt
python main.py      # solicita UAC automaticamente
# O sin consola:
run.bat
```

> **Nota:** Requiere privilegios de administrador para matar procesos y registrarse
> en el Programador de Tareas. Solicita elevacion UAC al ejecutarse sin privilegios.

---

## Instalacion general

### Backend FastAPI

```bash
cd backend
pip install -r requirements.txt
python main.py
# API REST:  http://localhost:8000
# Swagger:   http://localhost:8000/docs
# Admin:     http://localhost:8000/admin
```

### App Flutter

```bash
flutter pub get
flutter run
```

> Emulador Android: apunta a `http://10.0.2.2:8000` por defecto.
> Dispositivo fisico: cambia `apiBaseUrl` en `lib/core/constants/app_constants.dart` por la IP local.

---

## Dependencias

### Flutter (`pubspec.yaml`)

| Paquete | Version | Uso |
|---|---|---|
| `flutter_riverpod` | ^2.6.1 | Estado global |
| `hive_flutter` | ^1.1.0 | Almacenamiento local |
| `http` | ^1.2.2 | Cliente HTTP hacia el backend |
| `table_calendar` | ^3.1.2 | UI de calendario |
| `flutter_local_notifications` | ^17.2.4 | Notificaciones push |
| `android_alarm_manager_plus` | ^5.0.0 | Alarmas en background |
| `google_fonts` | ^6.2.1 | Plus Jakarta Sans |
| `uuid` | ^4.5.1 | Generacion de IDs |

### Backend Python (`backend/requirements.txt`)

| Paquete | Uso |
|---|---|
| `fastapi` | Framework API REST |
| `uvicorn` | Servidor ASGI |
| `sqlalchemy` | ORM SQLite |
| `pydantic` | Validacion de schemas |
| `jinja2` | Templates HTML (admin panel) |

### FocusGuard Python (`focusguard/requirements.txt`)

| Paquete | Uso |
|---|---|
| `psutil` | Monitoreo y terminacion de procesos |
| `plyer` | Notificaciones de escritorio |
| `tkcalendar` | Widget de calendario en Tkinter |

---

## Modelo de datos: Task

El mismo esquema de tarea se usa en los tres componentes:

| Campo | Tipo | Descripcion |
|---|---|---|
| `id` | UUID string | Generado por el cliente |
| `title` | string | Titulo de la tarea |
| `date` | ISO 8601 | Fecha asignada |
| `start_time` / `end_time` | ISO 8601 | Horario (opcional) |
| `status` | 0/1/2 | Pendiente / En progreso / Completada |
| `mode` | 0/1 | Calendario / Smart Mode |
| `category_id` | int FK | Categoria (solo app + backend) |
| `recurrence` | JSON | Regla: daily / weekly / monthly / yearly |
| `is_carried_over` | bool | Tarea arrastrada del dia anterior |
| `day_order` | int | Orden dentro del dia |
