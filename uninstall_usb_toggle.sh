#!/usr/bin/env bash
set -euo pipefail

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

if [[ -z "${USER_NAME}" || -z "${USER_HOME}" ]]; then
  echo "No pude determinar usuario/HOME. Abortando."
  exit 1
fi

APP_DIR="${USER_HOME}/iledesma/itoggleusb"
DESKTOP_DIR="${USER_HOME}/Desktop"

echo "[*] Eliminando scripts en ${APP_DIR}..."
rm -f "${APP_DIR}/usb-off.sh" "${APP_DIR}/usb-on.sh" 2>/dev/null || true

# Limpieza opcional de scripts viejos en ~/bin (por si quedaron)
if [[ -d "${USER_HOME}/bin" ]]; then
  rm -f "${USER_HOME}/bin/usb-off.sh" "${USER_HOME}/bin/usb-on.sh" 2>/dev/null || true
fi

# Intentar borrar el directorio si quedó vacío
if [[ -d "${APP_DIR}" ]]; then
  rmdir --ignore-fail-on-non-empty "${APP_DIR}" 2>/dev/null || true
  rmdir --ignore-fail-on-non-empty "${USER_HOME}/iledesma" 2>/dev/null || true
fi

echo "[*] Eliminando accesos directos del escritorio..."
rm -f "${DESKTOP_DIR}/USB-Off.desktop" "${DESKTOP_DIR}/USB-On.desktop" 2>/dev/null || true

echo "[*] Restaurando configuración de usb-storage (si estaba bloqueado)..."
if [[ -f /etc/modprobe.d/disable-usb-storage.conf ]]; then
  sudo rm -f /etc/modprobe.d/disable-usb-storage.conf
  sudo update-initramfs -u
  notify-send "USB Mass Storage" "🔓 Habilitado (usb-storage disponible)"
fi

echo
echo "✅ Desinstalación completa."
echo "Se borraron scripts y lanzadores."
echo "El módulo usb-storage está habilitado nuevamente."
echo
echo "Tip: verificá el estado del módulo:"
echo "  lsmod | grep usb_storage || echo 'usb_storage no está cargado (normal si no hay pendrive conectado)'"
