# 🐾 Evaluación: Contenerización con Docker — *carrera-docker*

## Objetivo

Demostrar que puedes **contenerizar una aplicación de tres capas** (frontend, backend y base de datos) utilizando Docker y Docker Compose.

## 🏁 Dinámica de la carrera

Evaluación **presencial e individual**. Cada estudiante compite por levantar la aplicación desde cero:

1. Crea tus archivos de Docker y levanta la aplicación con `docker compose up --build`.
2. Cuando `verificar.sh` pasa todas las pruebas, avisa al docente para registrar tu orden de llegada.
3. **Validación cruzada:** entrega al docente la carpeta completa del proyecto, incluido tu `.env` (por ejemplo, en un `.zip`). El docente la ejecutará después **en su propia máquina**, sin modificar nada.
4. Si no funciona en la máquina del docente, recibes la **penalización** indicada en los criterios de evaluación.

Se te entrega una aplicación funcional compuesta por:

| Capa | Tecnología | Puerto |
|------|-----------|--------|
| **Frontend** | HTML + JavaScript puro (servido con Node.js) | 3000 |
| **Backend** | Python 3.12 + FastAPI | 8000 |
| **Base de datos** | MySQL 8.4 | 3306 (solo interno) |

**Tu tarea es crear los archivos de Docker necesarios para que todo funcione con un solo `docker compose up --build`.**

---

## Estructura del repositorio

```
carrera-docker/
├── backend/
│   ├── main.py              ← API REST (NO MODIFICAR)
│   └── requirements.txt     ← Dependencias Python (NO MODIFICAR)
├── frontend/
│   ├── index.html           ← Página web (NO MODIFICAR)
│   └── package.json         ← Dependencias Node (NO MODIFICAR)
├── db/
│   └── init.sql             ← Script SQL de inicialización (NO MODIFICAR)
├── .env.example             ← Plantilla de variables de entorno
├── .gitignore
├── README.md                ← Este archivo
└── verificar.sh             ← Script de verificación automática
```

---

## ¿Qué debes entregar?

Debes crear **en la raíz del proyecto** los siguientes archivos:

| Archivo | Descripción |
|---------|-------------|
| `backend/Dockerfile` | Imagen Docker para el backend Python |
| `frontend/Dockerfile` | Imagen Docker para el frontend |
| `docker-compose.yml` | Orquestación de los 3 servicios |
| `.env` | Variables de entorno (basado en `.env.example`) |
| `.dockerignore` | Archivos a excluir del contexto de build |

---

## Requisitos técnicos

### 1. `backend/Dockerfile`
- Imagen base: [`python:3.12-slim`](https://hub.docker.com/_/python)
- Definir un `WORKDIR`.
- Copiar `requirements.txt` **antes** que el resto del código (para aprovechar la caché de capas).
- Instalar las dependencias del proyecto. Revisa `requirements.txt` para saber cuáles son y cómo instalarlas sin dejar caché.
- Exponer el puerto adecuado. Revisa `main.py` o la documentación de uvicorn para determinarlo.
- Iniciar la aplicación con `uvicorn` escuchando en todas las interfaces.

### 2. `frontend/Dockerfile`
- Imagen base: [`node:20-alpine`](https://hub.docker.com/_/node)
- Definir un `WORKDIR`.
- Copiar `package.json` **antes** que el resto (para aprovechar la caché de capas) e instalar las dependencias con `npm install`.
- Copiar `index.html`.
- Exponer el puerto 3000.
- Iniciar la aplicación con `npm start`.

### 3. `docker-compose.yml`
Debe definir **tres servicios**:

#### Servicio `db` (MySQL)
- Imagen: [`mysql:8.4`](https://hub.docker.com/_/mysql)
- Configurar las variables de entorno que la imagen de MySQL necesita para crear la base de datos y el usuario. Consulta la documentación de la imagen.
- Volumen nombrado para persistencia de datos.
- Montar `db/init.sql` en la ruta de inicialización de MySQL (solo lectura). Revisa la documentación de la imagen para saber cuál es.
- Healthcheck con `mysqladmin ping`.
- **NO publicar puertos al host.**

#### Servicio `back` (Backend)
- Build desde `./backend`.
- Publicar el puerto en que escucha la API.
- Cargar variables de entorno desde el archivo `.env`.
- Debe esperar a que la base de datos esté lista antes de arrancar (`depends_on` con condición `service_healthy`).

#### Servicio `front` (Frontend)
- Build desde `./frontend`.
- Publicar el puerto 3000.

### 4. `.env`
- Basado en `.env.example`.
- **`DB_HOST` debe apuntar al nombre del servicio de la base de datos en docker-compose** (no a `localhost`).

### 5. `.dockerignore`
- Excluir archivos que no son necesarios dentro de la imagen (caché de Python, control de versiones, variables de entorno, documentación, etc.).

---

## Variables de entorno

La aplicación se configura **exclusivamente** por variables de entorno:

| Variable | Descripción | ¿Obligatoria? |
|----------|-------------|:---:|
| `DB_HOST` | Host de la base de datos | ✅ |
| `DB_PORT` | Puerto de la base de datos | ✅ |
| `DB_NAME` | Nombre de la base de datos | ✅ |
| `DB_USER` | Usuario de la base de datos | ✅ |
| `DB_PASSWORD` | Contraseña de la base de datos | ✅ |
| `APP_MODE` | Modo de la aplicación | ❌ (default: `development`) |
| `APP_MESSAGE` | Mensaje mostrado en el frontend | ✅ |

---

## Endpoints de la API

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/health` | Estado de la API y conexión a BD |
| `GET` | `/mascotas` | Lista todas las mascotas |
| `POST` | `/mascotas` | Crea una mascota (`{nombre, especie}`) |
| `GET` | `/config` | Devuelve modo y mensaje de la app |

---

## Verificación

Después de levantar tu solución, ejecuta el script de verificación:

```bash
# Levantar la aplicación
docker compose up --build -d

# Esperar unos segundos a que arranque la BD
sleep 10

# Ejecutar la verificación
../verificar.sh "Bienvenido a la Clínica Veterinaria" "Luna"
```

El script comprueba automáticamente:
1. ✅ Al menos 3 contenedores corriendo
2. ✅ `GET /health` responde 200 con `db: ok`
3. ✅ `GET /mascotas` devuelve JSON
4. ✅ `GET /config` contiene el mensaje esperado
5. ✅ El frontend responde 200 en el puerto 3000
6. ✅ La mascota indicada aparece en la lista

---

## Pistas

- Recuerda que dentro de una red Docker, los servicios se comunican por **nombre de servicio**, no por `localhost`.
- El backend no arranca si falta alguna variable de entorno obligatoria. Revisa los logs con `docker compose logs back`.
- Si cambias el `init.sql` y no ves los cambios, recuerda que MySQL solo ejecuta los scripts de inicialización cuando el volumen está vacío. Usa `docker compose down -v` para borrar el volumen.
- Usa `docker compose ps` para verificar el estado de los contenedores.
- Usa `docker compose logs <servicio>` para depurar errores.

---

## Criterios de evaluación

| Criterio | Puntos |
|----------|:------:|
| `backend/Dockerfile` correcto | 3 |
| `frontend/Dockerfile` correcto | 2 |
| `docker-compose.yml` con los 3 servicios | 5 |
| Configuración con variables de entorno (`.env` correcto) | 2 |
| `.dockerignore` apropiado | 1 |
| `docker compose up --build` levanta y `verificar.sh` pasa todas las pruebas | 3 |
| Validación cruzada: funciona en la máquina del docente | 2 |
| Orden de llegada: 1.º = 2 · 2.º = 1,5 · 3.º = 1 · resto = 0,5 | 2 |
| **Total** | **20** |

**Penalización:** si la aplicación no funciona en la máquina del docente, se obtienen 0 puntos en validación cruzada y se restan 2 puntos adicionales.

---

> **⚠️ No modifiques** los archivos en `backend/`, `frontend/` ni `db/`. Solo crea los archivos de Docker indicados.

¡Buena suerte! 🐳
