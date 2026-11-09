"""
API REST para gestión de mascotas – Clínica Veterinaria.
Toda la configuración se lee de variables de entorno.
"""

import os
import sys
import logging

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import pymysql

# ──────────────────────────────────────────────
# Configuración de logs a stdout
# ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    stream=sys.stdout,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# Variables de entorno obligatorias
# ──────────────────────────────────────────────
REQUIRED_VARS = ["DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD", "APP_MESSAGE"]

for var in REQUIRED_VARS:
    if not os.environ.get(var):
        logger.error("Variable de entorno obligatoria no definida: %s", var)
        sys.exit(1)

DB_HOST = os.environ["DB_HOST"]
DB_PORT = int(os.environ["DB_PORT"])
DB_NAME = os.environ["DB_NAME"]
DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]
APP_MODE = os.environ.get("APP_MODE", "development")
APP_MESSAGE = os.environ["APP_MESSAGE"]

logger.info("Configuración cargada — DB_HOST=%s, DB_PORT=%d, DB_NAME=%s", DB_HOST, DB_PORT, DB_NAME)

# ──────────────────────────────────────────────
# Aplicación FastAPI
# ──────────────────────────────────────────────
app = FastAPI(title="Clínica Veterinaria API")

# CORS permitido solo para el frontend en :3000
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_connection():
    """Abre una conexión a MySQL. Se llama en cada petición."""
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
    )


# ── Modelo de entrada ────────────────────────
class MascotaIn(BaseModel):
    nombre: str | None = None
    especie: str | None = None


# ── Endpoints ────────────────────────────────

@app.get("/health")
def health():
    """Verifica la conexión a la base de datos."""
    try:
        conn = get_connection()
        conn.ping()
        conn.close()
        logger.info("Health check OK")
        return {"status": "ok", "db": "ok"}
    except Exception as exc:
        logger.warning("Health check fallido: %s", exc)
        return JSONResponse(status_code=503, content={"status": "error", "db": "down"})


@app.get("/mascotas")
def listar_mascotas():
    """Devuelve todas las mascotas registradas."""
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, nombre, especie FROM mascotas")
            mascotas = cursor.fetchall()
        logger.info("Mascotas listadas: %d", len(mascotas))
        return mascotas
    finally:
        conn.close()


@app.post("/mascotas", status_code=201)
def crear_mascota(mascota: MascotaIn):
    """Crea una nueva mascota. Requiere nombre y especie no vacíos."""
    # Validar campos obligatorios
    if not mascota.nombre or not mascota.nombre.strip():
        raise HTTPException(status_code=400, detail="El campo 'nombre' es obligatorio.")
    if not mascota.especie or not mascota.especie.strip():
        raise HTTPException(status_code=400, detail="El campo 'especie' es obligatorio.")

    nombre = mascota.nombre.strip()
    especie = mascota.especie.strip()

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "INSERT INTO mascotas (nombre, especie) VALUES (%s, %s)",
                (nombre, especie),
            )
            conn.commit()
            nuevo_id = cursor.lastrowid
        logger.info("Mascota creada: id=%d, nombre=%s", nuevo_id, nombre)
        return {"id": nuevo_id, "nombre": nombre, "especie": especie}
    finally:
        conn.close()


@app.get("/config")
def config():
    """Devuelve la configuración visible de la aplicación."""
    return {"mode": APP_MODE, "message": APP_MESSAGE}

