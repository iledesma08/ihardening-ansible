#!/usr/bin/env bash
set -euo pipefail

# ===== Detectar usuario y HOME (sesión actual) =====
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

if [[ -z "$USER_NAME" || -z "$USER_HOME" ]]; then
  echo "No pude determinar usuario/HOME. Abortando."
  exit 1
fi

# ===== Checks básicos =====
command -v sudo >/dev/null 2>&1 || { echo "Necesitas sudo instalado."; exit 1; }
if ! id -nG "$USER_NAME" | grep -Eq '\b(sudo|wheel)\b'; then
  echo "El usuario '$USER_NAME' no está en sudo/wheel. Agregalo y reintentá."
  exit 1
fi

# ===== Paquetes necesarios =====
echo "[*] Instalando libnotify-bin (para notify-send)..."
sudo apt-get update -y
sudo apt-get install -y libnotify-bin

# ===== Directorios =====
APP_DIR="$USER_HOME/iledesma/itoggleusb"
DESKTOP_DIR="$USER_HOME/Desktop"
mkdir -p "$APP_DIR" "$DESKTOP_DIR"
sudo chown -R "$USER_NAME:$USER_NAME" "$APP_DIR" "$DESKTOP_DIR"
chmod 0755 "$APP_DIR" "$DESKTOP_DIR"

# ===== Script USB OFF =====
cat > "$APP_DIR/usb-off.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo 'install usb-storage /bin/true' | sudo tee /etc/modprobe.d/disable-usb-storage.conf >/dev/null
sudo update-initramfs -u
# Intentar descargar el módulo al vuelo (si no está en uso)
sudo modprobe -r usb-storage || true
notify-send "USB Mass Storage" "🔒 Deshabilitado (usb-storage bloqueado)"
EOF

# ===== Script USB ON =====
cat > "$APP_DIR/usb-on.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sudo rm -f /etc/modprobe.d/disable-usb-storage.conf
sudo update-initramfs -u
notify-send "USB Mass Storage" "🔓 Habilitado (usb-storage disponible)"
EOF

chmod 0755 "$APP_DIR/usb-off.sh" "$APP_DIR/usb-on.sh"
sudo chown "$USER_NAME:$USER_NAME" "$APP_DIR/usb-off.sh" "$APP_DIR/usb-on.sh"

# ===== Lanzadores .desktop (usando shell y terminal para sudo) =====
cat > "$DESKTOP_DIR/USB-Off.desktop" <<'EOF'
[Desktop Entry]
Name=USB Storage OFF
Comment=Deshabilitar almacenamiento masivo USB
Exec=/bin/bash -lc "$HOME/iledesma/itoggleusb/usb-off.sh"
Icon=drive-removable-media-usb
Type=Application
Terminal=true
EOF

cat > "$DESKTOP_DIR/USB-On.desktop" <<'EOF'
[Desktop Entry]
Name=USB Storage ON
Comment=Habilitar almacenamiento masivo USB
Exec=/bin/bash -lc "$HOME/iledesma/itoggleusb/usb-on.sh"
Icon=drive-removable-media
Type=Application
Terminal=true
EOF

chmod 0755 "$DESKTOP_DIR/USB-Off.desktop" "$DESKTOP_DIR/USB-On.desktop"
sudo chown "$USER_NAME:$USER_NAME" "$DESKTOP_DIR/USB-Off.desktop" "$DESKTOP_DIR/USB-On.desktop"

echo
echo "✅ Listo. Se crearon:"
echo "  - $APP_DIR/usb-off.sh"
echo "  - $APP_DIR/usb-on.sh"
echo "  - $DESKTOP_DIR/USB-Off.desktop"
echo "  - $DESKTOP_DIR/USB-On.desktop"
echo
echo "Usá los iconos del Escritorio. Abrirán una terminal y te pedirán la contraseña (sudo)."
echo
echo "Estado actual:"
if [[ -f /etc/modprobe.d/disable-usb-storage.conf ]]; then
  echo "  usb-storage: BLOQUEADO (archivo disable-usb-storage.conf presente)"
else
  echo "  usb-storage: HABILITADO"
fi
echo
echo "Tip: para ver si el módulo está cargado: lsmod | grep usb_storage"
