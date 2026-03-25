# FocusFlow — Smart Task Reminder & App Blocker

Aplicación móvil Android desarrollada con **Flutter** que integra un backend **FastAPI** para sincronización de tareas en la nube.

---

## Descripción general

FocusFlow es una app de productividad que combina:

- **Calendario interactivo** para organizar tareas por fecha
- **Modo inteligente** para agendar tareas sin hora fija
- **Bloqueo de apps** durante sesiones de enfoque
- **Recordatorios y alarmas** por tarea
- **Sincronización con backend CMS** para respaldo y administración remota de datos

---

## Arquitectura

```
FocusFlow
├── lib/                        # App Flutter (cliente Android)
│   ├── core/                   # Constantes y tema
│   ├── data/
│   │   ├── models/             # Task, Category, RecurrenceRule, BlockSession
│   │   └── repositories/       # TaskRepository (Hive – almacenamiento local)
│   ├── presentation/
│   │   ├── providers/          # Estado global (Riverpod)
│   │   └── screens/            # Calendar, SmartMode, Settings, Onboarding…
│   └── services/
│       ├── api_service.dart    # Cliente HTTP → backend CMS
│       ├── alarm_service.dart
│       ├── app_blocker_service.dart
│       └── scheduler_service.dart
│
└── backend/                    # CMS FastAPI (Python)
    ├── main.py                 # Punto de entrada + panel admin
    ├── models.py               # ORM SQLAlchemy (Task, Category)
    ├── schemas.py              # Schemas Pydantic
    ├── database.py             # Conexión SQLite
    ├── routers/
    │   ├── tasks.py            # CRUD + bulk sync
    │   └── categories.py       # CRUD categorías
    ├── static/
    │   └── index.html          # Panel de administración web
    └── requirements.txt
```

---

## Actualización: Backend CMS (FastAPI)

### ¿Qué se agregó?

Esta actualización incorpora un **backend REST API** que actúa como CMS (Content Management System) para la app móvil. El backend permite:

| Característica | Detalle |
|---|---|
| **API REST** | CRUD completo de tareas y categorías |
| **Bulk sync** | Endpoint `POST /api/tasks/bulk` para sincronizar todas las tareas locales en una sola petición |
| **Stats** | Endpoint `GET /api/stats` con totales por estado (pendiente, en progreso, completada) |
| **Panel admin** | Interfaz web en `/` y `/admin` para gestionar tareas desde el navegador |
| **Base de datos** | SQLite con SQLAlchemy 2.x |

### Endpoints del backend

**Tareas** `prefix: /api/tasks`

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/` | Listar tareas (filtros: `date`, `status`, `mode`, `category_id`) |
| `GET` | `/{id}` | Obtener tarea por ID |
| `POST` | `/` | Crear tarea |
| `PUT` | `/{id}` | Actualizar tarea |
| `DELETE` | `/{id}` | Eliminar tarea |
| `POST` | `/bulk` | Upsert masivo desde la app móvil |

**Categorías** `prefix: /api/categories`

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/` | Listar categorías |
| `POST` | `/` | Crear categoría |
| `PUT` | `/{id}` | Actualizar categoría |
| `DELETE` | `/{id}` | Eliminar (desvincula tareas asociadas) |

**Stats** — `GET /api/stats`

```json
{
  "total": 12,
  "pending": 4,
  "in_progress": 3,
  "completed": 5,
  "categories": 3
}
```

### Cambios en la app Flutter

- **`lib/services/api_service.dart`** — Nuevo cliente HTTP que consume el backend. Maneja conversión `camelCase ↔ snake_case` entre Flutter y Python.
- **`lib/data/models/category_model.dart`** — Nuevo modelo `Category` con id, name, color e icon.
- **`lib/presentation/providers/task_provider.dart`** — Nuevo método `syncWithServer()` para hacer bulk sync de todas las tareas locales al backend.
- **`lib/core/constants/app_constants.dart`** — Constante `apiBaseUrl` (`http://10.0.2.2:8000` para emulador Android; cambiar por IP local para dispositivo físico).
- **`pubspec.yaml`** — Dependencia `http: ^1.2.2` agregada.

---

## Modelo de datos: Task

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | String (UUID) | Generado por el cliente Flutter |
| `title` | String | Título de la tarea |
| `description` | Text | Descripción opcional |
| `date` | String (ISO 8601) | Fecha de la tarea |
| `start_time` | String (ISO 8601) | Hora de inicio (opcional) |
| `end_time` | String (ISO 8601) | Hora de fin (opcional) |
| `status` | Int | 0=pendiente, 1=en progreso, 2=completada |
| `mode` | Int | 0=calendario, 1=modo inteligente |
| `category_id` | Int (FK) | Categoría asignada (opcional) |
| `recurrence` | JSON string | Regla de recurrencia serializada |
| `is_carried_over` | Bool | Tarea arrastrada del día anterior |
| `day_order` | Int | Orden dentro del día |
| `parent_id` | String | ID de la tarea padre (recurrencia) |
| `is_recurring_parent` | Bool | Es tarea raíz de una serie recurrente |

---

## Instalación y ejecución

### Backend (Python ≥ 3.11)

```bash
cd backend
pip install -r requirements.txt
python main.py
```

El servidor queda disponible en `http://localhost:8000`.
Documentación automática: `http://localhost:8000/docs`
Panel de administración: `http://localhost:8000/admin`

### App Flutter (Android)

```bash
flutter pub get
flutter run
```

> **Nota:** Para correr en emulador Android, el backend ya apunta a `http://10.0.2.2:8000` (alias de `localhost` del host).
> Para dispositivo físico en la misma red Wi-Fi, cambiar `apiBaseUrl` en `lib/core/constants/app_constants.dart` por la IP local de tu máquina.

---

## Dependencias principales

### Flutter
| Paquete | Uso |
|---|---|
| `flutter_riverpod` | Estado global |
| `hive_flutter` | Almacenamiento local |
| `http` | Cliente HTTP para el backend |
| `table_calendar` | UI de calendario |
| `flutter_local_notifications` | Notificaciones |
| `android_alarm_manager_plus` | Alarmas en background |
| `uuid` | Generación de IDs únicos |

### Python / Backend
| Paquete | Uso |
|---|---|
| `fastapi` | Framework API REST |
| `uvicorn` | Servidor ASGI |
| `sqlalchemy` | ORM base de datos |
| `pydantic` | Validación de schemas |
