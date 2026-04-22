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
│   │   └── models/             # Task, Category, Social models
│   ├── presentation/
│   │   ├── providers/          # Riverpod: task, settings, social, sync, category
│   │   ├── screens/
│   │   │   ├── auth/           # Pantalla login/registro
│   │   │   ├── calendar/       # Vista calendario y alta de tareas
│   │   │   ├── home/           # Pantalla principal
│   │   │   ├── settings/       # Ajustes
│   │   │   ├── smart_mode/     # Modo inteligente
│   │   │   ├── social/         # Feed social, amigos, retos
│   │   │   └── task_detail_screen.dart
│   │   ├── shell/              # AppShell (navegacion raiz)
│   │   └── widgets/            # TaskCard y otros widgets reutilizables
│   └── services/               # api_service, social_api_service, task_mapper
├── backend/                    # CMS FastAPI (Dashboard web + API REST)
│   ├── main.py
│   ├── limiter.py              # Rate limiting (SlowAPI)
│   ├── routers/
│   │   ├── tasks.py
│   │   ├── categories.py
│   │   ├── users.py            # Auth: registro, login, tokens bcrypt
│   │   └── social.py           # Amigos, retos, feed
│   ├── static/index.html       # Panel de administracion
│   ├── Procfile                # Deploy Render/Heroku
│   └── render.yaml             # Configuracion deploy Render
├── focusguard/                 # Bloqueador de apps Windows
│   ├── main.py
│   ├── src/
│   │   ├── api_service.py      # Cliente HTTP autenticado al backend
│   │   ├── system_tray.py      # Icono de bandeja (pystray)
│   │   └── ...                 # blocker, config, ui, widgets, tray, etc.
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
- Tablas de gestion de tareas/categorias/usuarios con hover sutil
- Badges de estado con colores semanticos (pendiente/en progreso/completada)
- Indicador de conexion en tiempo real (punto verde animado al detectar el backend)

---

## Sistema de cuentas y red social

### Autenticacion (App movil)

**Pantalla:** `lib/presentation/screens/auth/auth_screen.dart`

- Tabs: **Login** / **Registro** con animacion de transicion
- Registro incluye: username, nombre, email, password, bio y avatar emoji
- Login almacena el token en `flutter_secure_storage` (nunca en texto plano)
- Provider: `lib/presentation/providers/social_provider.dart`

### Feed social (App movil)

**Pantalla:** `lib/presentation/screens/social/social_screen.dart`

3 tabs:
| Tab | Contenido |
|---|---|
| **Feed** | Publicaciones de productividad de amigos |
| **Amigos** | Lista de amigos, solicitudes pendientes, busqueda por username |
| **Retos** | Retos activos recibidos/enviados, crear nuevo reto |

### Backend — Endpoints de usuarios

`POST /api/users/register` — Registro  
`POST /api/users/login` — Login, devuelve token (TTL 30 dias)  
`GET /api/users/me` — Perfil propio  
`GET /api/users/` — Lista de usuarios *(requiere auth)*  
`PUT /api/users/{id}` — Actualizar perfil  
`DELETE /api/users/{id}` — Eliminar cuenta  

### Backend — Endpoints sociales

`GET /api/social/friends` — Lista de amigos  
`POST /api/social/friends/request` — Enviar solicitud de amistad  
`POST /api/social/friends/{id}/accept` — Aceptar solicitud  
`GET /api/social/challenges` — Retos activos  
`POST /api/social/challenges` — Crear reto  
`POST /api/social/challenges/{id}/complete` — Marcar reto completado  
`GET /api/social/feed` — Feed de actividad  

**Autenticacion:** Header `X-Token: <token>` en todos los endpoints protegidos.

---

## Conexion App Movil — Dashboard

### Flujo de datos

```
Flutter (Hive local)
       |
       |  HTTP JSON + X-Token
       v
FastAPI backend  ------>  SQLite / PostgreSQL (focusflow.db)
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
| `POST` | `/api/users/login` | Login, obtiene token |
| `POST` | `/api/users/register` | Registro de nueva cuenta |
| `GET` | `/api/social/feed` | Feed social |
| `GET` | `/api/social/friends` | Lista de amigos |

### Ciclo de sincronizacion (`lib/presentation/providers/task_provider.dart`)

1. `_init()` secuencial: local → servidor → expansion de recurrentes.
2. En cada CRUD: escribe en Hive primero (offline-first), luego sincroniza al servidor.
3. `syncWithServer()` hace `POST /api/tasks/bulk` con todas las tareas locales.

### Conversion de datos (`lib/services/task_mapper.dart`)

Centralizada en `TaskMapper` — `api_service.dart` delega a el.

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
| **Bandeja del sistema** | Minimiza a tray con menu contextual e indicador de estado (pystray) |
| **Sincronizacion** | Login al backend compartido — tareas sincronizadas con la app movil |
| **Aviso TLS** | Muestra advertencia visual si el backend usa HTTP sin cifrar |
| **Banner sin admin** | Advertencia roja visible si FocusGuard corre sin privilegios de administrador |

### Estructura de `focusguard/`

```
focusguard/
├── main.py           # Elevacion UAC, autostart, loop principal
├── requirements.txt  # psutil, plyer, tkcalendar, pystray, keyring
├── run.bat           # Lanzador sin consola (pythonw)
└── src/
    ├── api_service.py  # Cliente HTTP autenticado (X-Token via keyring)
    ├── system_tray.py  # Icono pystray, thread-safe con root.after()
    ├── config.py       # Singleton thread-safe, config JSON, reset diario
    ├── models.py       # Dataclasses: Task, RecurrenceRule, BlockSession
    ├── repository.py   # Persistencia JSON: tasks.json, sessions.json
    ├── blocker.py      # BlockerThread: daemon que mata procesos bloqueados
    ├── scheduler.py    # Generacion de tareas recurrentes
    ├── ui.py           # MainWindow: 4 pestanas (Inicio, Calendario, Smart, Ajustes)
    ├── widgets.py      # AnimatedBar, PulsingDot, CheckBox, helpers de tema
    └── tray.py         # Icono de bandeja + notificaciones de escritorio
```

### UI de FocusGuard

- **Temas:** Claro / Oscuro con cambio en tiempo real
- **Colores de acento:** Azul / Rojo / Verde (coherentes con la app movil)
- **Widgets personalizados:**
  - `AnimatedBar` — barra de progreso con interpolacion de color
  - `PulsingDot` — indicador pulsante de sesion activa
  - `CheckBox` — casilla con estilo coherente al tema
- **Tab Ajustes:**
  - Campo URL del backend con aviso amarillo si usa HTTP
  - Seccion "Cuenta": estado de sesion, botones Login / Logout
  - Banner rojo si no hay privilegios de administrador

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

#### Deploy en Render

El backend incluye `Procfile` y `render.yaml` listos para desplegar en [Render.com](https://render.com).
Copia `.env.example` a `.env` y configura las variables de entorno antes del deploy.

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
| `flutter_secure_storage` | ^10.0.0 | Token de sesion cifrado |
| `table_calendar` | ^3.1.2 | UI de calendario |
| `flutter_local_notifications` | ^17.2.4 | Notificaciones push |
| `android_alarm_manager_plus` | ^5.0.0 | Alarmas en background |
| `google_fonts` | ^6.2.1 | Plus Jakarta Sans |
| `flutter_colorpicker` | ^1.0.3 | Selector de color de acento |
| `animate_do` | ^3.3.4 | Animaciones de entrada |
| `uuid` | ^4.5.1 | Generacion de IDs |
| `shared_preferences` | ^2.3.3 | Comunicacion con servicio Kotlin |
| `permission_handler` | ^11.3.1 | Permisos Android |

### Backend Python (`backend/requirements.txt`)

| Paquete | Uso |
|---|---|
| `fastapi` | Framework API REST |
| `uvicorn[standard]` | Servidor ASGI |
| `sqlalchemy` | ORM SQLite / PostgreSQL |
| `pydantic` | Validacion de schemas |
| `jinja2` | Templates HTML (admin panel) |
| `bcrypt` | Hash seguro de passwords |
| `slowapi` | Rate limiting por IP |
| `python-dotenv` | Variables de entorno |
| `psycopg2-binary` | Driver PostgreSQL (deploy) |

### FocusGuard Python (`focusguard/requirements.txt`)

| Paquete | Uso |
|---|---|
| `psutil` | Monitoreo y terminacion de procesos |
| `plyer` | Notificaciones de escritorio |
| `tkcalendar` | Widget de calendario en Tkinter |
| `pystray` | Icono de bandeja del sistema |
| `Pillow` | Icono para el tray |
| `requests` | Cliente HTTP al backend |
| `keyring` | Token de sesion en Windows Credential Manager |

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

---

## Historial de revisiones de codigo

### FocusFlow (App movil) — Revision 2026-04-14

Se identificaron y resolvieron **18 issues** clasificados en 4 categorias:

#### Criticos de seguridad — RESUELTOS

| # | Problema | Solucion |
|---|----------|----------|
| 1 | `CORS allow_origins=["*"]` con `allow_credentials=True` | `allow_credentials=False` en `backend/main.py` |
| 2 | `GET /api/users/` sin autenticacion | `Depends(get_current_user)` en todos los endpoints de usuarios |
| 3 | Token social guardado en Hive (texto plano) | Migrado a `flutter_secure_storage` en `social_provider.dart` |
| 4 | Passwords con SHA-256 sin salt | bcrypt con migracion transparente de hashes legacy en `users.py` |

#### Crashes en runtime — RESUELTOS

| # | Problema | Solucion |
|---|----------|----------|
| 5 | Race condition en constructor de `TaskNotifier` | Reemplazado por `_init()` secuencial (local → servidor → expansion) |
| 6 | `firstWhere()` sin fallback — crash si la tarea fue borrada | Reemplazado por `indexWhere + guard` en mark\* |
| 7 | `jsonDecode(recurrence)` — crash si `recurrence` es null | Helper `_parseRecurrence()` defensivo con try-catch |

#### Bugs logicos — RESUELTOS

| # | Problema | Solucion |
|---|----------|----------|
| 8 | `completedBlocks` no se resetea al romperse la racha | Se resetea a 0 en `recordTaskCompletion()` al detectar dia nuevo |
| 9 | Tareas sin hora nunca hacen carry-over (se pierden) | Tareas sin `endTime` se llevan a hoy si su fecha es anterior |
| 10 | Sequential lock falla silenciosamente | `markCompleted` devuelve `bool`; SnackBar de feedback en UI |
| 11 | Challenge sin validar `start_date < end_date` | Validacion ISO + comparacion de fechas en `social.py` |

#### Rendimiento — RESUELTOS

| # | Problema | Solucion |
|---|----------|----------|
| 12 | `serverStatsProvider` autoDispose — GET en cada navegacion | Removido `autoDispose`; `ref.invalidate` en pull-to-refresh |
| 13 | `todayTasksProvider` observa todo el estado | Usa `select` para evitar recalcular con cambios de otros dias |
| 14 | `taskExistsOnDate()` O(n) dentro de un loop | Set O(1) en `expandRecurringTasks` |

#### Deuda tecnica — RESUELTA

| # | Problema | Solucion |
|---|----------|----------|
| 15 | Sin tests | `computeStreak` como funcion pura (6 tests Flutter) + `test_api.py` (9 tests backend) |
| 16 | Sin logging | `logging.basicConfig` en backend; `dart:developer` en `task_provider.dart` |
| 17 | Conversion camelCase↔snake_case duplicada | Centralizada en `lib/services/task_mapper.dart` |
| 18 | `TaskNotifier` instancia dependencias directamente | Acepta `repo/alarm/blocker/scheduler` opcionales para mocks |

---

### FocusGuard (Desktop) — Revision 2026-04-15

Se identificaron **18 issues**. Los criticos de seguridad fueron resueltos el 2026-04-17.

#### Criticos de seguridad — RESUELTOS

| # | Problema | Solucion |
|---|----------|----------|
| 1 | API sin autenticacion (ningun endpoint enviaba credenciales) | `keyring` para guardar token; `ApiService` envia `X-Token`; `LoginDialog` en Ajustes |
| 2 | HTTP sin TLS + sin `verify=True` | `verify=True` explicito en todos los `requests.*`; aviso visual si URL usa http:// |
| 3 | UAC bypass (`--no-admin`) sin ninguna advertencia visible | Banner rojo en Ajustes + log INFO del estado admin en cada arranque |
| 4 | Path sin escapar en `schtasks` (posible inyeccion de argumentos) | `_schtasks_escape()` elimina comillas dobles del path antes de armar el comando |

#### Crashes en runtime — PENDIENTES

| # | Problema | Detalle |
|---|----------|---------|
| 5 | Tkinter llamado desde hilo pystray | `open_main()` en el callback del tray no usa `root.after()` (a diferencia de `exit_app`) |
| 6 | UI thread bloqueado por disk I/O dentro de `cfg._lock` | `BlockerThread` y UI compiten por el lock cada 3-5 s |
| 7 | `RecurrenceRule.next_occurrence` ignora `AFTER_OCCURRENCES` | Recurrencias con limite nunca terminan |

#### Bugs logicos — PENDIENTES

| # | Problema |
|---|----------|
| 8 | `save_history` lee del formato legacy → streak siempre 0 |
| 9 | Streak se rompe durante el dia actual (loop empieza en i=0) |
| 10 | Sin tareas asignadas → bloqueo permanente hasta `unlock_hour` |
| 11 | `pull_from_api(None)` al inicio sobreescribe cambios offline |

#### Rendimiento — PENDIENTE

| # | Problema |
|---|----------|
| 12 | `get_all_tasks()` sin cache — lectura de disco en cada llamada |
| 13 | `is_blocking_active()` lee tasks.json sosteniendo el lock global |
| 14 | `task_exists_on_date()` O(n) lectura de disco por llamada |

#### Deuda tecnica — PENDIENTE

| # | Problema |
|---|----------|
| 15 | Sin tests — bloqueo, scheduler, streak y sync sin cobertura |
| 16 | Logica de historial en `config.py` en lugar de `repository.py` |
| 17 | `BlockerThread` importa `config` directamente — no se puede testear con mocks |
| 18 | Reset de `blocks_date` triplicado en `config.py` — inconsistente |
