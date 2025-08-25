
# 🔐 Hardening Linux con Ansible (Cátedra Criptografía y Seguridad en Redes)

Este repositorio contiene playbooks de **Ansible** y utilidades para automatizar el **endurecimiento de sistemas Linux**.  
Está diseñado para cumplir las **exigencias de auditoría de Lynis** en el marco de la cátedra **Criptografía y Seguridad en Redes**.

## 📦 Contenido

- `site.yml` → Playbook principal con tareas de hardening.
- `inventory` → Archivo de inventario de Ansible.
- `install_usb_toggle.sh` → Script que instala accesos directos para activar/desactivar almacenamiento masivo USB.
- `uninstall_usb_toggle.sh` → Script para eliminar los accesos directos y restaurar configuración.

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
  * La inicialización puede tardar varios minutos (escanea todo el sistema).
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
* **GRUB password**: es opcional, pero recomendado en entornos multiusuario o servidores.
* **USB toggle**: es una medida práctica para pruebas; en entornos de producción suele recomendarse soluciones como **USBGuard**.

## 📚 Recursos

* [Lynis Security Auditing](https://cisofy.com/lynis/)
* [Ansible Documentation](https://docs.ansible.com/)

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
