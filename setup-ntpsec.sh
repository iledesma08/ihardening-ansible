#!/usr/bin/env bash
set -euo pipefail

# === Parámetros editables ===
NTP_CONF="/etc/ntp.conf"
BACKUP_DIR="/etc/ntpconf-backups"
DATE_TAG="$(date +%Y%m%d-%H%M%S)"

# Config NTPsec SIN pool público (solo servidores NTS explícitos)
#!/usr/bin/env bash
set -euo pipefail

NTP_CONF="/etc/ntpsec/ntp.conf"
BACKUP_DIR="/etc/ntpsec/ntpconf-backups"
DATE_TAG="$(date +%Y%m%d-%H%M%S)"

NTP_CONF_CONTENT="$(cat <<'EOF'
# =======================
# NTPsec - configuración segura con NTS (sin pool público)
# =======================

# Servidores con NTS (autenticación TLS)
server time.cloudflare.com nts
server time.google.com nts
server nts.netnod.se nts
server ntp.inti.gob.ar nts

# Endurecimiento de consultas/control
restrict default kod limited nomodify nopeer noquery notrap
restrict -6 default kod limited nomodify nopeer noquery notrap
restrict 127.0.0.1
restrict ::1

# Solo cliente: no exponemos UDP/123 hacia la red
interface ignore wildcard
interface listen 127.0.0.1

# Archivo de deriva del reloj
driftfile /var/lib/ntp/drift
EOF
)"

# --- Utilitarios ---
msg() { printf "\n\033[1;32m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err() { printf "\n\033[1;31m[ERROR]\033[0m %s\n" "$*"; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Necesitás ejecutar este script con sudo o como root."
    exit 1
  fi
}

pkg_exists_apt() { dpkg -s "$1" &>/dev/null; }
svc_exists() { systemctl list-unit-files | awk '{print $1}' | grep -qx "$1"; }
svc_active() { systemctl is-active --quiet "$1"; }

# --- Inicio ---
require_root

# Verificar gestor de paquetes
if ! command -v apt &>/dev/null; then
  err "No se encontró 'apt'. Este script está pensado para Linux Mint/Ubuntu/Debian."
  exit 1
fi

# 1) Instalar NTPsec si hace falta
if pkg_exists_apt ntpsec; then
  msg "NTPsec ya está instalado."
else
  msg "Instalando NTPsec..."
  apt update -y
  apt install -y ntpsec
fi

# 2) Confirmar binario/versión
if command -v ntpd &>/dev/null; then
  VER="$(ntpd --version 2>&1 || true)"
  if grep -qi "ntpsec" <<<"$VER"; then
    msg "ntpd es provisto por NTPsec: $VER"
  else
    warn "ntpd no parece ser NTPsec. Versión detectada: $VER"
  fi
else
  err "No se encontró el binario 'ntpd' tras instalar ntpsec."
  exit 1
fi

# 3) Backup de config y escritura de la nueva
mkdir -p "$BACKUP_DIR"
if [[ -f "$NTP_CONF" ]]; then
  cp -a "$NTP_CONF" "$BACKUP_DIR/ntp.conf.$DATE_TAG.bak"
  msg "Backup de $NTP_CONF en $BACKUP_DIR/ntp.conf.$DATE_TAG.bak"
fi
printf "%s\n" "$NTP_CONF_CONTENT" > "$NTP_CONF"
msg "Se escribió configuración segura (sin pool público) en $NTP_CONF"

# 4) Determinar nombre del servicio
NTP_SVC="ntpsec.service"
if ! svc_exists "$NTP_SVC"; then
  if svc_exists "ntp.service"; then
    NTP_SVC="ntp.service"
  else
    err "No encuentro ni ntpsec.service ni ntp.service."
    systemctl list-unit-files | grep -E 'ntp|ntpsec' || true
    exit 1
  fi
fi

# 5) Deshabilitar systemd-timesyncd si corresponde
if svc_exists "systemd-timesyncd.service"; then
  if systemctl is-enabled --quiet systemd-timesyncd.service || svc_active systemd-timesyncd.service; then
    msg "Deshabilitando y deteniendo systemd-timesyncd..."
    systemctl disable --now systemd-timesyncd.service || warn "No se pudo deshabilitar/detener systemd-timesyncd."
  else
    msg "systemd-timesyncd ya está deshabilitado."
  fi
fi

# 6) Habilitar y reiniciar NTPsec
msg "Habilitando y reiniciando $NTP_SVC..."
systemctl enable --now "$NTP_SVC"
systemctl restart "$NTP_SVC"

sleep 2

# 7) Verificación rápida
msg "Estado del servicio:"
systemctl --no-pager --full status "$NTP_SVC" || true

msg "Peers NTP (ntpq -p):"
if command -v ntpq &>/dev/null; then
  ntpq -p || true
else
  warn "No se encontró 'ntpq'."
fi

if command -v ntpstat &>/dev/null; then
  msg "Estado de sincronización (ntpstat):"
  ntpstat || true
fi

msg "Listo. NTPsec instalado, configurado con NTS (sin pool público) y systemd-timesyncd deshabilitado."
echo "Backup(s) en: $BACKUP_DIR"
