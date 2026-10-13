# Día 1 · Instalación de Ubuntu Server y acceso SSH

## 1. Equipo anfitrión (PC cliente)
| Recurso | Valor |
|---|---|
| CPU | Intel Core i7-10870H (8 núcleos / 16 hilos) |
| RAM | 31,8 GB |
| Disco libre | ~259 GB (C:) |
| Virtualizador | VirtualBox 7.2.2 |
| IP del PC en la red solo-anfitrión | 192.168.56.20 |

## 2. Máquina virtual
| Recurso | Valor |
|---|---|
| Nombre | abaco-lab |
| SO | Ubuntu Server 24.04 LTS |
| vCPU / RAM / Disco | 2 / 4 GB / 40 GB |
| Adaptador 1 | NAT (salida a Internet) |
| Adaptador 2 | Solo-anfitrión (PC ↔ VM) |
| Hostname | abacolab |
| Usuario (con sudo) | samiabaco |
| Disco | LVM: `/` (ubuntu-lv) ampliado de 18,5 a ~36,9 GB · `/boot` 2 GB · `/boot/efi` 1 GB |
| enp0s3 (NAT) | 10.0.2.15/24 (DHCP de VirtualBox) |
| enp0s8 (solo-anfitrión) | 192.168.56.102/24 (DHCP de la red solo-anfitrión) |

## 3. Esquema
```
  [ PC Windows 192.168.56.20 ] --(solo-anfitrión)--> [ VM abacolab 192.168.56.102 ]
                                                          |
                                                        (NAT, 10.0.2.15) --> Internet
```

## 4. Comandos usados
| Comando | Dónde | Para qué | Resultado |
|---|---|---|---|
| `VBoxManage showvminfo abaco-lab` | PC | Revisar la VM antes de arrancar | Detectados adaptador 2 desactivado y tipo SO "Windows 11"; corregidos |
| `ip -br a` | VM | Ver interfaces e IPs | enp0s3 10.0.2.15, enp0s8 192.168.56.102 |
| `ping -c 3 ubuntu.com` | VM | Comprobar salida a Internet y DNS | 3/3 recibidos, 0 % pérdida, ~35 ms |
| `ping 192.168.56.102` | PC | Comprobar que el PC llega a la VM | Responde (<1 ms) |
| `sudo apt update` / `sudo apt upgrade -y` | VM | Lista de paquetes y aplicar actualizaciones | Sistema actualizado |

## Incidencias durante la instalación
- **Tipo de SO "Windows 11"** al crear la VM → cambiado a Ubuntu (64-bit) antes de arrancar.
- **Adaptador 2 desactivado** → habilitado como solo-anfitrión. Sin él no habría acceso SSH desde el PC.
- **`ubuntu-lv` usaba solo la mitad del grupo de volúmenes (18,5 GB)** → ampliado al máximo en el instalador.

## 5. SSH y UFW

### Clave SSH (en el PC)
| Paso | Comando | Notas |
|---|---|---|
| Primera conexión (contraseña) | `ssh samiabaco@192.168.56.102` | Se acepta la huella ED25519 del servidor y se guarda en `known_hosts` |
| Crear par de claves | `ssh-keygen -t ed25519 -C "samiabaco@abaco-lab"` | Ruta por defecto `C:\Users\ghall\.ssh\id_ed25519`, sin passphrase (laboratorio) |
| Copiar **solo la pública** | `type $env:USERPROFILE\.ssh\id_ed25519.pub \| ssh samiabaco@192.168.56.102 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"` | Windows no trae `ssh-copy-id` |
| Probar la clave | `ssh samiabaco@192.168.56.102` | Entra sin pedir la contraseña de la VM |

La clave privada **no sale del PC** y no está en este repositorio.

### Cortafuegos (en la VM)
```bash
sudo ufw allow from 192.168.56.20 to any port 22 proto tcp   # primero permitir
sudo ufw enable                                              # después activar
sudo ufw status verbose
```
Resultado: `Default: deny (incoming), allow (outgoing)`; única regla `22/tcp ALLOW IN 192.168.56.20`.
Solo el PC del laboratorio puede abrir conexiones SSH.

### Configuración del servidor SSH
```bash
echo "PermitRootLogin no" | sudo tee /etc/ssh/sshd_config.d/99-abaco.conf
sudo sshd -t                                   # validar: sin salida = correcto
sudo sshd -T | grep -i permitrootlogin         # → permitrootlogin no
sudo systemctl reload ssh
```
- `sshd -t` sin `sudo` da `50-cloud-init.conf: Permission denied` porque ese archivo es `600 root`.
- **Pendiente (miércoles):** `50-cloud-init.conf` mantiene `PasswordAuthentication yes`. Como sshd usa el
  primer valor que encuentra (orden alfabético), un `99-` no lo puede anular.

### Otros ajustes
- Zona horaria: `sudo timedatectl set-timezone Europe/Madrid`, para que los logs coincidan con la hora del PC.

## 6. Prueba tras reinicio
1. Se abrió una **segunda sesión** con clave y `sudo whoami` → `root`, antes de cerrar la primera.
2. `sudo reboot`. La sesión antigua quedó "fantasma" (ventana abierta, conexión muerta).
3. Nueva conexión con clave tras el reinicio ✅. `uptime -s` → `2026-10-13 17:33:10`.
4. En el log de `systemctl status ssh` aparece `Accepted publickey for samiabaco from 192.168.56.20 ... ED25519`.

Nota: `ssh.service` aparece como `disabled` y `TriggeredBy: ssh.socket`. En Ubuntu 24.04, SSH arranca **bajo
demanda**: systemd escucha el puerto 22 y lanza sshd al llegar una conexión. Por eso funciona tras reiniciar.

### Evidencias (`evidencias/dia1/`)
| Archivo | Contenido |
|---|---|
| `salidas-dia1.txt` | `hostnamectl`, `ip -br a`, `df -h`, `free -h`, `systemctl status ssh`, `sshd_config.d`, `uptime`, `last reboot` |
| `01-instalador-almacenamiento-lvm.png` | `ubuntu-lv` a la mitad (18,5 GB) antes de ampliarlo |
| `02-ping-internet.png` | Ping a ubuntu.com (salida por NAT y DNS) |
| `03-ip-br-a-y-ls-home.png` | IPs de la VM y carpeta personal |
| `04-practica-permisos.png` | Práctica de `chmod`, `chown`, `sudo` |
| `05-ufw-status.png` | UFW activo con la regla 22/tcp |
| `06-` y `07-verificacion-tras-reinicio` | Comprobaciones tras el reinicio: sistema, disco (37 GB en `/`), RAM, SSH y UFW |

Resumen: `/` 37 GB (6,5 GB usados) · RAM 3,8 GiB (406 MiB usados) · swap 3,8 GiB · Ubuntu 24.04.5 LTS, kernel 6.8.0-147.

## 7. Qué he aprendido / qué falta
_pendiente_
