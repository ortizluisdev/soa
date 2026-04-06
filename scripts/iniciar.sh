#!/bin/bash
# ════════════════════════════════════════════════════
# SOA v2.2 — iniciar.sh
# Inicia: validación de env → Docker (postgres/redis/evolution/n8n) → deploy server
# Uso: bash ~/soa/scripts/iniciar.sh
# ════════════════════════════════════════════════════

set -euo pipefail

SOA_BASE="$HOME/soa"
ENV_FILE="$SOA_BASE/.env"
DEPLOY_DIR="$SOA_BASE/deploy"
LOG_DIR="$SOA_BASE/logs"
DEPLOY_LOG="$LOG_DIR/deploy_server.log"
DEPLOY_PID="$SOA_BASE/temp/deploy.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
AMBER='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
warn() { echo -e "${AMBER}[WARN]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${CYAN}[SOA]${NC}   $1"; }

echo ""
info "════════════════════════════════════════"
info "   SOA v2.2 — Iniciando sistema"
info "════════════════════════════════════════"
echo ""

# ── 1. Validar .env ───────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  err "No se encontró $ENV_FILE"
  err "Crea el archivo .env antes de iniciar."
  exit 1
fi

info "Ejecutando validar_env.sh..."
bash "$SOA_BASE/scripts/validar_env.sh" || {
  err "Validación de .env fallida. Corrige los errores antes de continuar."
  exit 1
}

# ── 2. Crear directorios necesarios ──────────────
mkdir -p "$LOG_DIR" "$SOA_BASE/temp" "$SOA_BASE/output" \
         "$SOA_BASE/rollback" "$SOA_BASE/workspace" \
         "$SOA_BASE/context"

# Inicializar archivos temp si no existen
[ ! -f "$SOA_BASE/temp/iteraciones.json" ] && \
  echo '{"ia1_ia2":0,"ia3":0}' > "$SOA_BASE/temp/iteraciones.json"
[ ! -f "$SOA_BASE/temp/evasiones.json" ] && \
  echo '{"ia1":0,"ia2":0,"ia3":0}' > "$SOA_BASE/temp/evasiones.json"
[ ! -f "$SOA_BASE/workspace/archivo_activo.txt" ] && \
  touch "$SOA_BASE/workspace/archivo_activo.txt"

ok "Directorios y archivos temp listos"

# ── 3. Verificar Docker ───────────────────────────
if ! command -v docker &>/dev/null; then
  err "Docker no encontrado. Instala Docker antes de continuar."
  exit 1
fi

if ! docker info &>/dev/null; then
  err "Docker daemon no está corriendo. Inicia Docker primero."
  exit 1
fi

ok "Docker disponible"

# ── 4. Iniciar contenedores ───────────────────────
info "Iniciando contenedores Docker..."
cd "$SOA_BASE"

# Fix CRLF en .env si existe
sed -i 's/\r//' "$ENV_FILE"

docker compose up -d

# Esperar a que evolution_api esté listo
info "Esperando a que Evolution API esté lista..."
RETRIES=0
MAX_RETRIES=20
until docker logs soa_evolution 2>&1 | grep -q "Server is listening\|Application is running\|start:prod" || [ $RETRIES -ge $MAX_RETRIES ]; do
  sleep 3
  RETRIES=$((RETRIES+1))
  echo -n "."
done
echo ""

if [ $RETRIES -ge $MAX_RETRIES ]; then
  warn "Evolution API tardó más de lo esperado. Verifica: docker logs soa_evolution"
else
  ok "Evolution API lista"
fi

# ── 5. Iniciar deploy server ──────────────────────
if [ ! -f "$DEPLOY_DIR/server.js" ]; then
  warn "No se encontró $DEPLOY_DIR/server.js — deploy server no iniciado"
else
  # Matar instancia anterior si existe
  if [ -f "$DEPLOY_PID" ]; then
    OLD_PID=$(cat "$DEPLOY_PID" 2>/dev/null || echo "")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
      info "Deteniendo deploy server anterior (PID: $OLD_PID)..."
      kill "$OLD_PID" 2>/dev/null || true
      sleep 1
    fi
  fi

  info "Iniciando deploy server en puerto 3000..."
  cd "$DEPLOY_DIR"
  # Cargar variables del .env
  export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs) 2>/dev/null || true
  nohup node server.js >> "$DEPLOY_LOG" 2>&1 &
  DEPLOY_PID_VAL=$!
  echo $DEPLOY_PID_VAL > "$DEPLOY_PID"
  sleep 2

  if kill -0 "$DEPLOY_PID_VAL" 2>/dev/null; then
    ok "Deploy server corriendo (PID: $DEPLOY_PID_VAL) → http://localhost:3000"
  else
    err "Deploy server no pudo iniciar. Revisa: $DEPLOY_LOG"
  fi
fi

# ── 6. Resumen ────────────────────────────────────
echo ""
info "════════════════════════════════════════"
info "   SOA listo"
info "════════════════════════════════════════"
echo -e "  ${CYAN}n8n:${NC}          http://localhost:5678"
echo -e "  ${CYAN}Evolution API:${NC} http://localhost:8080"
echo -e "  ${CYAN}Deploy server:${NC} http://localhost:3000"
echo -e "  ${CYAN}Logs:${NC}          $LOG_DIR"
echo ""
info "Para monitorear: docker logs soa_evolution -f"
info "Para detener:    docker compose down"
echo ""