#!/bin/bash
# ════════════════════════════════════════════════════
# SOA v2.2 — rollback.sh
# Restaura el último .bak del directorio rollback/
# También acepta un nombre específico como argumento.
# Equivalente a rollback.bat del documento original
# Uso: bash ~/soa/scripts/rollback.sh [nombre_backup.bak]
# ════════════════════════════════════════════════════

SOA_BASE="$HOME/soa"
ROLLBACK_DIR="$SOA_BASE/rollback"
OUTPUT_DIR="$SOA_BASE/output"
WORKSPACE_DIR="$SOA_BASE/workspace"

RED='\033[0;31m'
GREEN='\033[0;32m'
AMBER='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[SOA]${NC}   $1"; }
warn() { echo -e "${AMBER}[WARN]${NC}  $1"; }

# ── 1. Verificar que existe el directorio rollback ─
if [ ! -d "$ROLLBACK_DIR" ]; then
  err "No existe el directorio rollback: $ROLLBACK_DIR"
fi

# ── 2. Determinar qué backup restaurar ────────────
if [ -n "${1:-}" ]; then
  # Backup específico pasado como argumento
  BACKUP_NOMBRE="$1"
  BACKUP_PATH="$ROLLBACK_DIR/$BACKUP_NOMBRE"
  if [ ! -f "$BACKUP_PATH" ]; then
    err "No se encontró el backup: $BACKUP_PATH"
  fi
  info "Backup especificado: $BACKUP_NOMBRE"
else
  # Buscar el más reciente por fecha de modificación
  BACKUP_PATH=$(find "$ROLLBACK_DIR" -name "*.bak" -type f -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr | head -1 | awk '{print $2}')

  if [ -z "$BACKUP_PATH" ]; then
    err "No hay backups disponibles en $ROLLBACK_DIR"
  fi
  BACKUP_NOMBRE=$(basename "$BACKUP_PATH")
  info "Backup más reciente: $BACKUP_NOMBRE"
fi

# ── 3. Extraer nombre del archivo original ─────────
# Formato esperado: nombre_YYYYMMDD_HHMMSS.bak
# Extrae todo antes del último _YYYYMMDD_HHMMSS
NOMBRE_ORIGINAL=$(echo "$BACKUP_NOMBRE" | sed 's/_[0-9]\{8\}_[0-9]\{6\}\.bak$//')

# Si no tiene extensión en el nombre original, intentar detectarla
if [[ "$NOMBRE_ORIGINAL" != *.* ]]; then
  # Intentar leer la primera línea del backup para detectar tipo
  PRIMERA_LINEA=$(head -1 "$BACKUP_PATH" 2>/dev/null || echo "")
  warn "El backup no tiene extensión en el nombre. Archivo: $NOMBRE_ORIGINAL"
  info "Revisa manualmente el tipo de archivo."
fi

# ── 4. Verificar que hay un destino válido ─────────
# Intentar poner en output/ primero, sino en workspace/
if [ -d "$OUTPUT_DIR" ]; then
  DESTINO="$OUTPUT_DIR/$NOMBRE_ORIGINAL"
else
  DESTINO="$WORKSPACE_DIR/$NOMBRE_ORIGINAL"
fi

# ── 5. Confirmar rollback ─────────────────────────
echo ""
info "═══════════════════════════════════════"
info "   ROLLBACK SOA"
info "═══════════════════════════════════════"
echo -e "  Backup:   ${AMBER}$BACKUP_NOMBRE${NC}"
echo -e "  Destino:  ${CYAN}$DESTINO${NC}"
echo ""

# Si se ejecuta interactivamente, pedir confirmación
if [ -t 0 ]; then
  read -rp "¿Confirmar rollback? [s/N] " CONFIRMAR
  if [[ ! "$CONFIRMAR" =~ ^[sS]$ ]]; then
    warn "Rollback cancelado por el usuario."
    exit 0
  fi
fi

# ── 6. Ejecutar rollback ──────────────────────────
mkdir -p "$(dirname "$DESTINO")"
cp "$BACKUP_PATH" "$DESTINO"

if [ $? -eq 0 ]; then
  # Actualizar archivo_activo.txt con el archivo restaurado
  echo "$NOMBRE_ORIGINAL" > "$WORKSPACE_DIR/archivo_activo.txt"
  ok "Restaurado: $NOMBRE_ORIGINAL → $DESTINO"
  ok "archivo_activo.txt actualizado"
  
  # Log del rollback
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  mkdir -p "$HOME/soa/logs"
  echo "[$TIMESTAMP] ROLLBACK OK: $BACKUP_NOMBRE → $NOMBRE_ORIGINAL" >> "$HOME/soa/logs/rollback.log"
  
  echo ""
  echo -e "${GREEN}[SOA] Rollback exitoso: $NOMBRE_ORIGINAL${NC}"
else
  err "No se pudo copiar el backup a $DESTINO"
fi

# ── 7. Listar backups disponibles ─────────────────
echo ""
info "Backups disponibles en rollback/:"
find "$ROLLBACK_DIR" -name "*.bak" -type f -printf '%TY-%Tm-%Td %TH:%TM  %f\n' 2>/dev/null \
  | sort -r | head -10