#!/usr/bin/env bash
set -euo pipefail

# =========================
#  setup-ntpsec.sh
#  - Instala NTPsec (si falta)
#  - Escribe /etc/ntpsec/ntp.conf (NTS + INTI en clásico, sin pool público)
#  - Crea override systemd (sin wrapper ni include DHCP) con PIDFile correcto
#  - Deshabilita systemd-timesyncd
#  - Arranca no-bloqueante y verifica estado
# =========================

# --- Parámetros ---
NTP_CONF="/etc/ntpsec/ntp.conf"
BACKUP_DIR="/etc/ntpsec/ntpconf-backups"
DATE_TAG="$(date +%Y%m%d-%H%M%S)"
NTP_SVC="ntpsec.service"

# Contenido de ntp.conf (NTS + INTI NTP clásico; sin pool público)
NTP_CONF_CONTENT="$(cat <<'EOF'
# =======================
# NTPsec - configuración segura (NTS + INTI clásico, sin pool público)
# =======================
driftfile /var/lib/ntpsec/ntp.drift
leapfile /usr/share/zoneinfo/leap-seconds.list

# Servidores con NTS (se activarán cuando la red permita TCP/4460)
server time.cloudflare.com nts

# Servidor local (NTP clásico por UDP/123) para asegurar disponibilidad
server ntp.inti.gob.ar iburst

# Endurecimiento (cliente)
restrict default kod limited nomodify nopeer noquery
restrict -6 default kod limited nomodify nopeer noquery
restrict 127.0.0.1
restrict ::1
EOF
)"

# --- Utilitarios ---
msg()  { printf "\n\033[1;32m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\n\033[1;31m[ERROR]\033[0m %s\n" "$*"; }

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
  err "No se encontró 'ntpd' tras instalar ntpsec."
fi

# 3) Backup de config y escritura de la nueva
mkdir -p "$BACKUP_DIR"
if [[ -f "$NTP_CONF" ]]; then
  cp -a "$NTP_CONF" "$BACKUP_DIR/ntp.conf.$DATE_TAG.bak"
  msg "Backup de $NTP_CONF en $BACKUP_DIR/ntp.conf.$DATE_TAG.bak"
fi
printf "%s\n" "$NTP_CONF_CONTENT" > "$NTP_CONF"
msg "Se escribió configuración segura (sin pool público) en $NTP_CONF"

# 4) OVERRIDE SYSTEMD (forzar ntpd sin wrapper ni include DHCP)
msg "Creando override de systemd para ntpsec (evita que el DHCP asigne peers segun la red actual)..."
mkdir -p "/etc/systemd/system/${NTP_SVC}.d"
tee "/etc/systemd/system/${NTP_SVC}.d/override.conf" >/dev/null <<'INI'
[Service]
Type=forking
PIDFile=/run/ntpd.pid
ExecStart=
ExecStart=/usr/sbin/ntpd -g -u ntpsec:ntpsec -p /run/ntpd.pid -c /etc/ntpsec/ntp.conf
INI
systemctl daemon-reload

# 4.1) Limpieza de include DHCP temporal (si lo hubiese generado el wrapper)
rm -f /run/ntpsec/ntp.conf.dhcp || true

# 5) Deshabilitar systemd-timesyncd si corresponde
if svc_exists "systemd-timesyncd.service"; then
  if systemctl is-enabled --quiet systemd-timesyncd.service || svc_active systemd-timesyncd.service; then
    msg "Deshabilitando y deteniendo systemd-timesyncd..."
    systemctl disable --now systemd-timesyncd.service || warn "No se pudo deshabilitar/detener systemd-timesyncd."
  else
    msg "systemd-timesyncd ya está deshabilitado."
  fi
fi

# 6) Habilitar + start no-bloqueante y esperar a 'active'
msg "Habilitando $NTP_SVC y arrancando..."
systemctl enable "$NTP_SVC" || warn "enable devolvió no-0 (puede estar ya habilitado)."
systemctl start "$NTP_SVC" --no-block
sudo systemctl stop ntpsec
sudo rm -f /run/ntpsec/ntp.conf.dhcp
sudo systemctl start ntpsec

# Espera hasta 30s a que el servicio quede 'active'
for i in {1..30}; do
  if systemctl is-active --quiet "$NTP_SVC"; then
    break
  fi
  sleep 1
done

if ! systemctl is-active --quiet "$NTP_SVC"; then
  warn "$NTP_SVC no quedó active a tiempo. Últimos logs:"
  journalctl -u "$NTP_SVC" -n 80 --no-pager || true
fi

# 7) Verificación de peers
msg "Peers NTP (ntpq -p):"
if command -v ntpq &>/dev/null; then
  ntpq -p || true
else
  warn "No se encontró 'ntpq'."
fi

# 8) (Opcional) Mostrar asociaciones
if command -v ntpq &>/dev/null; then
  echo
  msg "Asociaciones detectadas:"
  ntpq -c associations | sed -n '1,200p' || true
fi

msg "Listo. NTPsec instalado, override aplicado y timesyncd deshabilitado."
echo "Backups en: $BACKUP_DIR"
