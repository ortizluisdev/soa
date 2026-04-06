#!/bin/bash
# ════════════════════════════════════════════════════
# SOA v2.2 — validar_env.sh
# Verifica que todas las variables críticas del .env
# están presentes y no tienen valores placeholder.
# Equivalente a validar_env.bat del documento original
# Uso: bash ~/soa/scripts/validar_env.sh
# ════════════════════════════════════════════════════

SOA_BASE="$HOME/soa"
ENV_FILE="$SOA_BASE/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
AMBER='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
err()  { echo -e "${RED}[FALTA]${NC} $1"; ERRORES=$((ERRORES+1)); }
warn() { echo -e "${AMBER}[WARN]${NC}  $1"; ADVERTENCIAS=$((ADVERTENCIAS+1)); }
info() { echo -e "${CYAN}[SOA]${NC}   $1"; }

ERRORES=0
ADVERTENCIAS=0

# ── Cargar .env ───────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  echo -e "${RED}[ERROR]${NC} No se encontró $ENV_FILE"
  exit 1
fi

# Fix CRLF
sed -i 's/\r//' "$ENV_FILE"

# Cargar variables
set -a
source "$ENV_FILE"
set +a

echo ""
info "════════════════════════════════════════"
info "   SOA v2.2 — Validación de .env"
info "   Archivo: $ENV_FILE"
info "════════════════════════════════════════"
echo ""

# ── Función de validación ──────────────────────────
check_var() {
  local VAR_NAME="$1"
  local DESCRIPCION="$2"
  local PLACEHOLDERS="${3:-xxxxxxx placeholder TU_USUARIO cambia_esto tu_token}"
  local ES_OPCIONAL="${4:-false}"

  local VALOR="${!VAR_NAME:-}"

  if [ -z "$VALOR" ]; then
    if [ "$ES_OPCIONAL" = "true" ]; then
      warn "$VAR_NAME no configurada (opcional) — $DESCRIPCION"
    else
      err "$VAR_NAME — $DESCRIPCION"
    fi
    return
  fi

  # Verificar si el valor es un placeholder
  for PLACEHOLDER in $PLACEHOLDERS; do
    if echo "$VALOR" | grep -qi "$PLACEHOLDER"; then
      warn "$VAR_NAME parece tener valor placeholder: $VALOR"
      ADVERTENCIAS=$((ADVERTENCIAS+1))
      return
    fi
  done

  ok "$VAR_NAME = ${VALOR:0:20}$([ ${#VALOR} -gt 20 ] && echo '...' || echo '')"
}

# ── SECCIÓN: APIs de IA ───────────────────────────
echo -e "${CYAN}── APIs de IA ──────────────────────────────${NC}"
check_var "OPENROUTER_API_KEY"  "API key de OpenRouter (IA1+IA2+IA3)" "xxxxxxx sk-or-xxx"
check_var "OPENROUTER_URL"      "URL de OpenRouter"
check_var "MODEL_IA1"           "Modelo para IA1 (GPT-4o)"
check_var "MODEL_IA2"           "Modelo para IA2 (Claude)"
check_var "MODEL_IA3"           "Modelo para IA3 (DeepSeek)"
check_var "OPENAI_API_KEY"      "API key de OpenAI (Whisper)" "xxxxxxx sk-xxx"
check_var "ANTHROPIC_API_KEY"   "API key de Anthropic (Claude Code)" "xxxxxxx sk-ant"
echo ""

# ── SECCIÓN: WhatsApp ─────────────────────────────
echo -e "${CYAN}── WhatsApp / Evolution API ────────────────${NC}"
check_var "WA_API_KEY"              "API key de Evolution API" "xxxxxxx mi_clave_secreta"
check_var "WA_NUMERO_AUTORIZADO"    "Número autorizado (con código de país)"
check_var "WA_INSTANCE"             "Nombre de instancia Evolution API"
check_var "CONFIG_SESSION_PHONE_VERSION" "Versión de WhatsApp Web para Baileys"
check_var "WEB_VERSION"             "Versión de WhatsApp Web (igual que CONFIG_SESSION_PHONE_VERSION)"
echo ""

# Verificar que CONFIG_SESSION_PHONE_VERSION y WEB_VERSION coincidan
if [ -n "${CONFIG_SESSION_PHONE_VERSION:-}" ] && [ -n "${WEB_VERSION:-}" ]; then
  if [ "$CONFIG_SESSION_PHONE_VERSION" = "$WEB_VERSION" ]; then
    ok "CONFIG_SESSION_PHONE_VERSION y WEB_VERSION coinciden ✓"
  else
    warn "CONFIG_SESSION_PHONE_VERSION ($CONFIG_SESSION_PHONE_VERSION) ≠ WEB_VERSION ($WEB_VERSION) — deben ser iguales"
  fi
fi

# ── SECCIÓN: n8n ─────────────────────────────────
echo -e "${CYAN}── n8n ─────────────────────────────────────${NC}"
check_var "N8N_USER"            "Usuario de n8n"
check_var "N8N_PASSWORD"        "Contraseña de n8n" "xxxxxxx password"
check_var "N8N_ENCRYPTION_KEY"  "Clave de cifrado n8n (mín 32 chars)"
check_var "N8N_WEBHOOK_KEY"     "Clave del webhook protegido"
echo ""

# Verificar longitud de N8N_ENCRYPTION_KEY
if [ -n "${N8N_ENCRYPTION_KEY:-}" ] && [ ${#N8N_ENCRYPTION_KEY} -lt 32 ]; then
  warn "N8N_ENCRYPTION_KEY es muy corta (${#N8N_ENCRYPTION_KEY} chars, mínimo 32)"
fi

# ── SECCIÓN: Ngrok ────────────────────────────────
echo -e "${CYAN}── Ngrok ───────────────────────────────────${NC}"
check_var "NGROK_URL"           "URL pública de Ngrok" "xxxxxxx tu_token"
check_var "NGROK_AUTH_TOKEN"    "Token de autenticación Ngrok" "xxxxxxx tu_token"
echo ""

# ── SECCIÓN: PostgreSQL ───────────────────────────
echo -e "${CYAN}── PostgreSQL ──────────────────────────────${NC}"
check_var "POSTGRES_PASSWORD"   "Contraseña de PostgreSQL" "cambia_esto password"
echo ""

# ── SECCIÓN: VPS (opcional para modo local) ───────
echo -e "${CYAN}── VPS (opcional en modo local) ────────────${NC}"
check_var "VPS_HOST"            "IP o dominio del VPS" "" "true"
check_var "VPS_USER"            "Usuario SSH del VPS" "" "true"
check_var "VPS_SSH_KEY_PATH"    "Ruta a la clave SSH privada" "TU_USUARIO" "true"
echo ""

# ── Verificar docker compose ──────────────────────
echo -e "${CYAN}── Entorno ─────────────────────────────────${NC}"
if command -v docker &>/dev/null; then
  ok "docker $(docker --version | grep -oP '[\d.]+'  | head -1) disponible"
else
  err "docker no encontrado — instala Docker"
fi

if [ -f "$SOA_BASE/docker-compose.yml" ]; then
  ok "docker-compose.yml encontrado"
else
  err "docker-compose.yml no encontrado en $SOA_BASE"
fi

if command -v node &>/dev/null; then
  ok "node $(node --version) disponible"
else
  warn "node no encontrado — necesario para el deploy server"
fi

if [ -f "$SOA_BASE/deploy/server.js" ]; then
  ok "deploy/server.js encontrado"
else
  warn "deploy/server.js no encontrado — deploy local no disponible"
fi
echo ""

# ── Resultado final ───────────────────────────────
info "════════════════════════════════════════"
if [ $ERRORES -gt 0 ]; then
  echo -e "${RED}   RESULTADO: $ERRORES error(es) — corrige antes de iniciar${NC}"
  echo -e "${AMBER}   Advertencias: $ADVERTENCIAS${NC}"
  info "════════════════════════════════════════"
  echo ""
  exit 1
elif [ $ADVERTENCIAS -gt 0 ]; then
  echo -e "${AMBER}   RESULTADO: OK con $ADVERTENCIAS advertencia(s)${NC}"
  info "════════════════════════════════════════"
  echo ""
  exit 0
else
  echo -e "${GREEN}   RESULTADO: TODO OK — sistema listo para iniciar${NC}"
  info "════════════════════════════════════════"
  echo ""
  exit 0
fi