#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# verificar.sh – Script de verificación de la evaluación
# Uso: ./verificar.sh "<mensaje esperado>" "<nombre de mascota>"
# Ejemplo: ./verificar.sh "Bienvenido a la Clínica Veterinaria" "Rex"
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── Argumentos ───────────────────────────────────────────────
if [ $# -lt 2 ]; then
  echo "Uso: $0 \"<mensaje esperado para /config>\" \"<nombre de mascota creada>\""
  exit 1
fi

MENSAJE_ESPERADO="$1"
MASCOTA_ESPERADA="$2"

PASS=0
FAIL=0

# ── Función auxiliar para reportar resultado ─────────────────
check() {
  local descripcion="$1"
  local resultado="$2" # "ok" o "fail"
  if [ "$resultado" = "ok" ]; then
    echo "  ✅ OK    — $descripcion"
    PASS=$((PASS + 1))
  else
    echo "  ❌ FALLA — $descripcion"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Verificación de la evaluación «carrera-docker»"
echo "══════════════════════════════════════════════════════════"
echo ""

# ── 1. Tres contenedores corriendo ──────────────────────────
echo "▶ Contenedores Docker"
RUNNING=$(docker compose ps --status running --format '{{.Name}}' 2>/dev/null | wc -l)
if [ "$RUNNING" -ge 3 ]; then
  check "Al menos 3 contenedores corriendo ($RUNNING encontrados)" "ok"
else
  check "Al menos 3 contenedores corriendo ($RUNNING encontrados)" "fail"
fi

# ── 2. GET /health ──────────────────────────────────────────
echo ""
echo "▶ Health check (GET /health)"
HTTP_CODE=$(curl -s -o /tmp/health.json -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  DB_STATUS=$(cat /tmp/health.json | grep -o '"db":"ok"' || true)
  if [ -n "$DB_STATUS" ]; then
    check "GET /health → 200 con db ok" "ok"
  else
    check "GET /health → 200 pero db no reporta ok" "fail"
  fi
else
  check "GET /health → esperado 200, obtenido $HTTP_CODE" "fail"
fi

# ── 3. GET /mascotas ────────────────────────────────────────
echo ""
echo "▶ Lista de mascotas (GET /mascotas)"
HTTP_CODE=$(curl -s -o /tmp/mascotas.json -w "%{http_code}" http://localhost:8000/mascotas 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  # Verificar que es JSON (comienza con '[')
  FIRST_CHAR=$(head -c 1 /tmp/mascotas.json)
  if [ "$FIRST_CHAR" = "[" ]; then
    check "GET /mascotas → 200, respuesta JSON válida" "ok"
  else
    check "GET /mascotas → 200 pero la respuesta no es un arreglo JSON" "fail"
  fi
else
  check "GET /mascotas → esperado 200, obtenido $HTTP_CODE" "fail"
fi

# ── 4. GET /config con mensaje esperado ─────────────────────
echo ""
echo "▶ Configuración (GET /config)"
HTTP_CODE=$(curl -s -o /tmp/config.json -w "%{http_code}" http://localhost:8000/config 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  MSG_FOUND=$(cat /tmp/config.json | grep -o "$MENSAJE_ESPERADO" || true)
  if [ -n "$MSG_FOUND" ]; then
    check "GET /config → contiene el mensaje esperado" "ok"
  else
    check "GET /config → mensaje esperado no encontrado" "fail"
    echo "        Esperado: $MENSAJE_ESPERADO"
    echo "        Obtenido: $(cat /tmp/config.json)"
  fi
else
  check "GET /config → esperado 200, obtenido $HTTP_CODE" "fail"
fi

# ── 5. Frontend responde en :3000 ──────────────────────────
echo ""
echo "▶ Frontend (GET http://localhost:3000)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  check "Frontend responde 200 en :3000" "ok"
else
  check "Frontend responde en :3000 → esperado 200, obtenido $HTTP_CODE" "fail"
fi

# ── 6. Mascota esperada existe en GET /mascotas ─────────────
echo ""
echo "▶ Mascota «$MASCOTA_ESPERADA» en la lista"
MASCOTA_FOUND=$(cat /tmp/mascotas.json 2>/dev/null | grep -o "$MASCOTA_ESPERADA" || true)
if [ -n "$MASCOTA_FOUND" ]; then
  check "Mascota «$MASCOTA_ESPERADA» encontrada en GET /mascotas" "ok"
else
  check "Mascota «$MASCOTA_ESPERADA» no encontrada en GET /mascotas" "fail"
fi

# ── Resumen ─────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
echo "  Resultado: $PASS/$TOTAL pruebas pasaron"
if [ "$FAIL" -gt 0 ]; then
  echo "  ⚠️  $FAIL prueba(s) fallaron."
  echo "══════════════════════════════════════════════════════════"
  exit 1
else
  echo "  🎉 ¡Todas las pruebas pasaron!"
  echo "══════════════════════════════════════════════════════════"
  exit 0
fi

