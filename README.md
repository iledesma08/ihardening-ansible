# 🔐 Hardening Linux con Ansible (Cátedra Criptografía y Seguridad en Redes)

Este repositorio contiene playbooks de **Ansible** y utilidades para automatizar el **endurecimiento de sistemas Linux**.  
Está diseñado para cumplir las **exigencias de auditoría de Lynis** en el marco de la cátedra **Criptografía y Seguridad en Redes**.

## 📦 Contenido

- `site.yml` → Playbook principal con tareas de hardening.
- `inventory` → Archivo de inventario de Ansible.
- `install_usb_toggle.sh` → Script que instala accesos directos para activar/desactivar almacenamiento masivo USB.
- `uninstall_usb_toggle.sh` → Script para eliminar los accesos directos y restaurar configuración.
- `setup-ntpsec.sh` → Script para instalar y configurar **NTPsec** con servidores seguros (Cloudflare, Google, Netnod y INTI).

## 🚀 Requisitos

- **Linux basado en Debian/Ubuntu/Mint**
- **Ansible** instalado:
  
  ```bash
  sudo apt install ansible
  ```

- Acceso con `sudo`.

## ▶️ Uso del Playbook de Hardening

Cloná el repositorio y entrá en la carpeta que contiene `site.yml`:

```bash
git clone https://github.com/iledesma08/ihardening-ansible.git
cd ihardening-ansible
````

Ejecutar el playbook principal:

```bash
ansible-playbook -i inventory site.yml -K
```

El parámetro `-K` hace que solicite tu contraseña de `sudo`.

### 🔹 Opciones interactivas

Durante la ejecución se te preguntará:

* **Inicializar AIDE DB** (`yes/no`)

  * AIDE es una herramienta de **integridad de archivos**.
  * ⚠️ La inicialización puede tardar **varios** minutos (escanea todo el sistema).
  * Si contestás `no`, Lynis te advertirá que falta la base de datos.

* **Configurar GRUB password** (`yes/no`)

  * Si contestás `yes`, se te pedirá:

    * **Usuario de GRUB** (ej: `root`)
    * **Hash PBKDF2** generado con:

      ```bash
      grub-mkpasswd-pbkdf2
      ```

  * Esto agrega un superusuario y protege la edición de GRUB.

### 🔹 Skipping AIDE o GRUB desde la línea de comandos

También podés saltear estas preguntas al ejecutar:

```bash
ansible-playbook -i inventory site.yml -K -e aide_init_choice=no -e set_grub_password=no
```

De esta forma no se pedirá nada sobre AIDE ni GRUB.

## 🛡️ Verificación con RKHunter

Luego de aplicar el playbook de Ansible se recomienda ejecutar **RKHunter** (Rootkit Hunter) para detectar rootkits y configuraciones inseguras.

### 🔹 Ejecución manual

```bash
sudo rkhunter --update
sudo rkhunter --propupd   # actualizar base de referencia de archivos
sudo rkhunter --check --sk
````

### 🔹 Resultados

* El escaneo mostrará advertencias y posibles problemas.
* El log completo se encuentra en:

  ```
  /var/log/rkhunter.log
  ```

De esta forma tendrás un reporte complementario a **Lynis** para validar el hardening.

## 🌐 Configuración Segura de NTP con NTPsec

El repositorio incluye un script `setup-ntpsec.sh` que:

* Instala **NTPsec** si no está presente.
* Configura `/etc/ntpsec/ntp.conf` con servidores confiables:

  * `time.cloudflare.com` (NTS)
  * `time.google.com` (NTS)
  * `nts.netnod.se` (NTS)
  * `ntp.inti.gob.ar` (servidor oficial del INTI en Argentina, modo NTP clásico)
* Aplica endurecimiento (`restrict`, `interface ignore`).
* Hace backup de configuraciones previas en `/etc/ntpsec/ntpconf-backups/`.
* Deshabilita `systemd-timesyncd` para evitar conflictos.
* Reinicia el servicio y muestra el estado (`systemctl status ntpsec`, `ntpq -p`).

### 🔹 Uso

```bash
chmod +x setup-ntpsec.sh
sudo ./setup-ntpsec.sh
```

### 🔹 Verificación

* Estado de servidores configurados:

  ```bash
  ntpq -p
  ```
* Chequeo de autenticación NTS:

  ```bash
  ntpq -c associations
  ntpq -c "ntpdata <associd>"
  ```

## 💽 Gestión de USB Mass Storage

Incluye scripts para habilitar/deshabilitar el módulo `usb-storage` desde el Escritorio.

### 🔹 Instalación

```bash
bash install_usb_toggle.sh
```

Esto crea:

* Carpeta `~/iledesma/itoggleusb/` con los scripts:

  * `usb-off.sh` → Deshabilita USB storage.
  * `usb-on.sh` → Habilita USB storage.
* Accesos directos en el Escritorio:

  * `USB-Off.desktop`
  * `USB-On.desktop`

Cada vez que ejecutes un icono se abrirá una terminal y pedirá tu contraseña `sudo`.

### 🔹 Desinstalación

```bash
bash uninstall_usb_toggle.sh
```

Esto elimina los scripts, accesos directos y restaura `usb-storage`.

### 🔹 Notificaciones

Al habilitar o deshabilitar se mostrará un aviso en pantalla con `notify-send`.

## 📋 Notas Importantes

* **AIDE**: sin base de datos inicial, Lynis seguirá mostrando advertencias.  
  Si el playbook parece trabarse en `TASK [Gathering Facts]`, puede deberse a que
  la base de datos de AIDE quedó corrupta o incompleta.  
  En ese caso, eliminá los archivos en `/var/lib/aide/` y volvé a correr el playbook:

  ```bash
  sudo rm -f /var/lib/aide/aide.db*
  ```
* **GRUB password**: es opcional, pero recomendado en entornos multiusuario o servidores.
* **USB toggle**: es una medida práctica para pruebas; en entornos de producción suele recomendarse soluciones como **USBGuard**.
* **NTPsec**: es preferible a `systemd-timesyncd` para entornos críticos; usá NTS siempre que sea posible. El servidor del **INTI** se incluye como respaldo confiable local.

## 📚 Recursos

* [Lynis Security Auditing](https://cisofy.com/lynis/)
* [Ansible Documentation](https://docs.ansible.com/)
* [NTPsec Project](https://ntpsec.org/)
* [INTI Argentina - Hora oficial](https://www.inti.gob.ar/)

## 🤝 Contribuciones

Las contribuciones son bienvenidas.
Si encontrás mejoras o querés agregar nuevas tareas de hardening:

1. Hacé un fork del repositorio.
2. Creá una rama para tu cambio (`git checkout -b mi-mejora`).
3. Commit y push (`git commit -m "Agrego X"`).
4. Abrí un Pull Request.

Sugerencias de la cátedra (scripts, configuraciones adicionales, etc.) también son aceptadas.

## 👥 Créditos

Trabajo desarrollado para la cátedra **Criptografía y Seguridad en Redes**.
Autor: *Ignacio Ledesma*
