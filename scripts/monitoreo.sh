#!/bin/bash
# ════════════════════════════════════════════════════
# SOA v2.2 — monitoreo.sh
# Monitorea VPS y n8n cada vez que se ejecuta.
# Configurar como cron cada 5 minutos:
#   */5 * * * * bash /home/TU_USUARIO/soa/scripts/monitoreo.sh
# Equivalente a monitoreo.bat del documento original
# ════════════════════════════════════════════════════

SOA_BASE="$HOME/soa"
ENV_FILE="$SOA_BASE/.env"
LOG_DIR="$SOA_BASE/logs"
LOG_FILE="$LOG_DIR/monitoreo.log"
MAX_LOG_LINES=5000   # rotar log si supera este tamaño

# Cargar variables del .env
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | sed 's/\r//' | xargs) 2>/dev/null || true
fi

VPS_HOST="${VPS_HOST:-}"
N8N_PORT="${N8N_PORT:-5678}"
NGROK_URL="${NGROK_URL:-}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$LOG_DIR"

# ── Función de alerta a n8n ───────────────────────
enviar_alerta() {
  local mensaje="$1"
  # Intentar alertar via webhook n8n local
  curl -s --max-time 5 -X POST "http://localhost:${N8N_PORT}/webhook/alerta-vps" \
    -H "Content-Type: application/json" \
    -d "{\"mensaje\":\"${mensaje}\"}" >/dev/null 2>&1 || true
}

# ── Rotar log si es muy grande ────────────────────
if [ -f "$LOG_FILE" ]; then
  LINEAS=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
  if [ "$LINEAS" -gt "$MAX_LOG_LINES" ]; then
    tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
fi

# ── 1. Verificar VPS ──────────────────────────────
if [ -z "$VPS_HOST" ]; then
  echo "[$TIMESTAMP] WARN  VPS_HOST no configurado en .env" >> "$LOG_FILE"
else
  if ping -c 3 -W 3 "$VPS_HOST" >/dev/null 2>&1; then
    echo "[$TIMESTAMP] OK    VPS $VPS_HOST accesible" >> "$LOG_FILE"
  else
    echo "[$TIMESTAMP] ERROR VPS $VPS_HOST CAIDO" >> "$LOG_FILE"
    enviar_alerta "🔴 ALERTA SOA: VPS ${VPS_HOST} no responde a ping — ${TIMESTAMP}"
    echo "[$TIMESTAMP] ALERTA enviada a n8n" >> "$LOG_FILE"
  fi
fi

# ── 2. Verificar contenedores Docker ─────────────
if command -v docker &>/dev/null; then
  for CONTAINER in soa_evolution soa_n8n soa_postgres soa_redis; do
    STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "no encontrado")
    if [ "$STATUS" = "running" ]; then
      echo "[$TIMESTAMP] OK    $CONTAINER running" >> "$LOG_FILE"
    else
      echo "[$TIMESTAMP] ERROR $CONTAINER STATUS=$STATUS" >> "$LOG_FILE"
      enviar_alerta "🔴 ALERTA SOA: Contenedor ${CONTAINER} en estado ${STATUS} — ${TIMESTAMP}"
    fi
  done
fi

# ── 3. Verificar deploy server (puerto 3000) ──────
if curl -s --max-time 3 http://localhost:3000/health >/dev/null 2>&1; then
  echo "[$TIMESTAMP] OK    Deploy server puerto 3000 respondiendo" >> "$LOG_FILE"
else
  echo "[$TIMESTAMP] WARN  Deploy server no responde en puerto 3000" >> "$LOG_FILE"
fi

# ── 4. Verificar n8n ──────────────────────────────
if curl -s --max-time 5 "http://localhost:${N8N_PORT}/healthz" >/dev/null 2>&1; then
  echo "[$TIMESTAMP] OK    n8n puerto ${N8N_PORT} respondiendo" >> "$LOG_FILE"
else
  echo "[$TIMESTAMP] WARN  n8n no responde en puerto ${N8N_PORT}" >> "$LOG_FILE"
fi

# ── 5. Mostrar últimas líneas del log ─────────────
# (útil cuando se ejecuta manualmente)
if [ -t 1 ]; then
  echo ""
  echo "=== Últimas entradas del monitoreo ==="
  tail -n 10 "$LOG_FILE"
fi