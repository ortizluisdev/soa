#!/bin/bash
# ════════════════════════════════════════════════════
# SOA v2.2 — limpiar.sh
# Limpieza post-ciclo: temp, backups viejos, archivo activo
# Equivalente a limpiar.bat del documento original
# Uso: bash ~/soa/scripts/limpiar.sh
# ════════════════════════════════════════════════════

SOA_BASE="$HOME/soa"
TEMP_DIR="$SOA_BASE/temp"
ROLLBACK_DIR="$SOA_BASE/rollback"
WORKSPACE_DIR="$SOA_BASE/workspace"
LOG_DIR="$SOA_BASE/logs"
DIAS_BACKUPS=7   # eliminar .bak con más de 7 días

GREEN='\033[0;32m'
AMBER='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
info() { echo -e "${CYAN}[SOA]${NC}   $1"; }

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
info "[$TIMESTAMP] Iniciando limpieza post-ciclo..."

# ── 1. Limpiar directorio temp ────────────────────
if [ -d "$TEMP_DIR" ]; then
  # Borrar todos los archivos dentro de temp
  find "$TEMP_DIR" -type f -delete
  find "$TEMP_DIR" -type d -not -path "$TEMP_DIR" -delete 2>/dev/null || true
  ok "temp/ limpiado"
else
  mkdir -p "$TEMP_DIR"
  ok "temp/ creado"
fi

# Reinicializar archivos de control
echo '{"ia1_ia2":0,"ia3":0}' > "$TEMP_DIR/iteraciones.json"
echo '{"ia1":0,"ia2":0,"ia3":0}' > "$TEMP_DIR/evasiones.json"
ok "Contadores de iteraciones y evasiones reiniciados"

# ── 2. Borrar backups viejos (> 7 días) ──────────
if [ -d "$ROLLBACK_DIR" ]; then
  BORRADOS=$(find "$ROLLBACK_DIR" -name "*.bak" -mtime +$DIAS_BACKUPS -type f 2>/dev/null | wc -l)
  find "$ROLLBACK_DIR" -name "*.bak" -mtime +$DIAS_BACKUPS -type f -delete 2>/dev/null || true
  if [ "$BORRADOS" -gt 0 ]; then
    ok "Eliminados $BORRADOS backups con más de $DIAS_BACKUPS días"
  else
    ok "No hay backups viejos que eliminar"
  fi
else
  mkdir -p "$ROLLBACK_DIR"
fi

# ── 3. Limpiar logs viejos (> 30 días) ───────────
if [ -d "$LOG_DIR" ]; then
  find "$LOG_DIR" -name "*.log" -mtime +30 -type f -delete 2>/dev/null || true
  ok "Logs de más de 30 días eliminados"
fi

# ── 4. Vaciar archivo_activo.txt ─────────────────
# (deja el puntero vacío para la próxima sesión)
echo -n "" > "$WORKSPACE_DIR/archivo_activo.txt"
ok "archivo_activo.txt vaciado — listo para nueva sesión"

# ── 5. Log de limpieza ────────────────────────────
mkdir -p "$LOG_DIR"
echo "[$TIMESTAMP] Limpieza completada" >> "$LOG_DIR/limpiar.log"

echo ""
echo -e "${GREEN}[SOA] Limpieza completada: $TIMESTAMP${NC}"