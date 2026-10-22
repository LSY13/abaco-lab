# abaco-lab

Laboratorio de la formación en servidores de Abaco (13-16 de octubre de 2026): Ubuntu Server 24.04, SSH,
Nginx y Docker Compose sobre una VM de VirtualBox. Todo en local, con datos ficticios y sin publicar nada en
Internet.

## Objetivo
Montar un servidor Ubuntu administrado desde otro equipo, publicar una web en dos entornos separados (DEV y
PRUEBAS) detrás de Nginx, hacer y restaurar una copia de seguridad y diagnosticar fallos con evidencias.

## Estado
| Día | Tema | Estado |
|---|---|---|
| Mar 13 | Instalar Ubuntu, SSH con clave y UFW | ✅ Hecho ([instalacion.md](documentacion/instalacion.md)) |
| Mié 14 | Nginx: dos sitios y proxy inverso | ✅ Hecho ([despliegue.md](documentacion/despliegue.md)) · SSH reforzado (sin contraseña ni root) · snapshot `dia2-nginx-ok` |
| Jue 15 | Docker Compose: DEV y PRUEBAS separados | ✅ Hecho ([despliegue.md](documentacion/despliegue.md), parte 2) · Docker oficial con `sudo docker` · Nginx delante de los contenedores · snapshot `dia3-docker-ok` |
| Vie 16 | Copias, restauración, diagnóstico y RCA | ✅ Línea base · ✅ Copia restaurada y validada ([backup-restore.md](documentacion/backup-restore.md)) · ✅ Fallos A (Nginx parado) y B (502) ([incidencia-rca.md](documentacion/incidencia-rca.md)) · RCA ([incidencia-rca.md](documentacion/incidencia-rca.md) §4) · ✅ Reinicio de comprobación ([incidencia-rca.md](documentacion/incidencia-rca.md) §5) · ✅ Demo en vídeo · ✅ snapshot `dia4-final` |
| 19-23 oct | Continuación: entorno ENSAYO, casos A-C y mejora de comprobación | ✅ ENSAYO (`ensayo.abaco.test`, `127.0.0.1:3011`, marcador y dato propios) · ✅ Casos A, B y C con pruebas · ✅ `comprobar-sitio.ps1` · snapshot `ensayo-ok` · todo en [continuacion/](continuacion/README.md) |

## Requisitos
| Elemento | Usado en este laboratorio |
|---|---|
| PC anfitrión | Windows 11 Pro, PowerShell, cliente OpenSSH (`ssh`, `scp`, `ssh-keygen`), navegador |
| Virtualizador | Oracle VirtualBox 7.2.2 |
| VM | Ubuntu Server 24.04.5 LTS · 2 vCPU · 4 GB de RAM · disco de 40 GB (volumen LVM ampliado al disco entero) |
| Red de la VM | Adaptador 1 **NAT** (Internet, 10.0.2.15) y adaptador 2 **solo-anfitrión** (192.168.56.0/24) |
| Software en la VM | OpenSSH server, UFW, Nginx 1.24.0, Docker Engine 29.9.1 y Docker Compose v5.6.0 (repositorio oficial de Docker) |
| Usuario | `samiabaco`, normal y con `sudo` (pide contraseña); sin grupo `docker` |

## Mapa
```
[ PC Windows 192.168.56.20 ] --(solo-anfitrión)--> [ VM abacolab 192.168.56.102 ]
  hosts: dev.abaco.test y                               | :22 SSH (solo con clave)
  pruebas.abaco.test → 192.168.56.102                   | :80 Nginx ─┬─ dev.abaco.test     → 127.0.0.1:3001 → contenedor DEV
                                                        |            └─ pruebas.abaco.test → 127.0.0.1:3002 → contenedor PRUEBAS
                                                      (NAT, 10.0.2.15) --> Internet
```
- Red solo-anfitrión 192.168.56.0/24: PC y VM en la misma subred, se hablan directamente.
- Red NAT 10.0.2.0/24: VirtualBox hace de router para que la VM salga a Internet.

## Seguridad aplicada
- SSH solo con clave (`PasswordAuthentication no`) y sin acceso de root (`PermitRootLogin no`), en `/etc/ssh/sshd_config.d/10-abaco.conf`.
- UFW: todo lo entrante denegado salvo lo necesario y solo desde el PC (192.168.56.20): 22 (SSH) y 80 (HTTP).
- Las aplicaciones detrás de Nginx escuchan solo en 127.0.0.1 (no accesibles desde fuera).
- Docker: `sudo docker`, sin grupo `docker` (equivale a root). Puertos publicados solo en `127.0.0.1`, porque
  Docker se salta UFW si publica en todas las interfaces.
- En el repositorio no hay claves privadas ni `.env` reales (`.gitignore`); solo `.env.example` sin secretos.

## Sitios
| URL (desde el PC, con `hosts`) | Qué sirve |
|---|---|
| `http://dev.abaco.test` | Nginx → `127.0.0.1:3001` → contenedor `abaco-dev-web-1` (imagen `abaco-web:dev-2`, volumen `abaco-dev_datos`) |
| `http://pruebas.abaco.test` | Nginx → `127.0.0.1:3002` → contenedor `abaco-pruebas-web-1` (imagen `abaco-web:pruebas-1`, volumen `abaco-pruebas_datos`) |

Hasta el día 2 los sitios eran archivos en `/var/www/` y `/app/` iba a una aplicación de Python en el 8080;
desde el día 3 los sirven los contenedores.

## Pasos para repetir el laboratorio
Resumen; el detalle, con salidas y capturas, está en cada documento.

1. **VM e instalación** ([instalacion.md](documentacion/instalacion.md) §1-4): crear la VM con NAT +
   solo-anfitrión, instalar Ubuntu Server 24.04 con OpenSSH y ampliar el volumen lógico al disco entero.
2. **SSH con clave y UFW** (§5): en el PC `ssh-keygen -t ed25519` y copiar **solo la clave pública** a
   `~/.ssh/authorized_keys` de la VM (Windows no trae `ssh-copy-id`: `type …\id_ed25519.pub | ssh …`); crear
   `/etc/ssh/sshd_config.d/10-abaco.conf` con `PasswordAuthentication no` y `PermitRootLogin no` (con un número
   menor que `50-cloud-init.conf`, porque en sshd gana el primer valor leído); UFW `default deny incoming` y
   permitir 22 y 80 solo desde 192.168.56.20.
3. **Nginx** ([despliegue.md](documentacion/despliegue.md) parte 1): `sudo apt install nginx`; copiar
   `nginx/dev.abaco.test` y `nginx/pruebas.abaco.test` a `/etc/nginx/sites-available/`, enlazarlos con `ln -s`
   en `sites-enabled/`, `sudo nginx -t` y `sudo systemctl reload nginx`.
4. **Nombres en el PC** (parte 1 §6): añadir a `C:\Windows\System32\drivers\etc\hosts` (PowerShell como
   administrador) `192.168.56.102  dev.abaco.test pruebas.abaco.test`.
5. **Docker** (parte 2 §3): instalar Docker Engine y el plugin de Compose desde el repositorio oficial.
6. **Proyectos** (parte 2 §4-5): `git clone` de este repositorio en la VM y, en `docker/dev/` y
   `docker/pruebas/`: `cp .env.example .env` y `sudo docker compose -p abaco-dev up -d --build` (o
   `-p abaco-pruebas`). El nombre de proyecto separa contenedores, redes y volúmenes.
7. **Dato de prueba** (parte 2 §10): escribir `dato DEV` / `dato PRUEBAS` en `/datos/prueba.txt` de cada
   contenedor (`sudo docker compose -p … exec web …`).
8. **Copia y restauración** ([backup-restore.md](documentacion/backup-restore.md)): `tar` de la configuración,
   copia del volumen con un contenedor temporal, `sha256sum`, `scp` al PC y restauración en una ubicación nueva.

## Pruebas
| Prueba | Comando | Resultado esperado |
|---|---|---|
| SSH con clave | `ssh samiabaco@192.168.56.102` (PC) | Entra sin pedir contraseña |
| Root bloqueado | `ssh root@192.168.56.102` (PC) | `Permission denied (publickey)` |
| Servicios | `systemctl is-active nginx docker` (VM) | `active` y `active` |
| DEV y PRUEBAS por Nginx | `curl.exe -I http://dev.abaco.test` y `http://pruebas.abaco.test` (PC) | `200` con `Server: nginx`; páginas DEV (versión 2) y PRUEBAS |
| Backends no expuestos | `curl.exe -m 5 http://192.168.56.102:3001` (PC) | Timeout (UFW lo bloquea) |
| Datos separados | `sudo docker compose -p abaco-dev exec web cat /datos/prueba.txt` (y `-p abaco-pruebas`) (VM) | `dato DEV` / `dato PRUEBAS` |
| Copia válida | `sha256sum -c SHA256SUMS` y `diff -r` ([backup-restore.md](documentacion/backup-restore.md) §6-7) | `OK` y sin diferencias |
| Tras reiniciar | `sudo reboot` y repetir lo anterior | Todo vuelve solo (servicios `enabled`, contenedores `restart: unless-stopped`); ✅ comprobado el 16 oct, [incidencia-rca.md](documentacion/incidencia-rca.md) §5 |

## Copias de seguridad
Copia de la configuración y del volumen `abaco-dev_datos`, restaurada y validada el 16 oct
([backup-restore.md](documentacion/backup-restore.md)). Se conserva fuera de la VM y del repositorio, en el PC:
`C:\Users\ghall\abaco-entrega\backups\` (con `SHA256SUMS`).

## Demostración
Vídeo con SSH, DEV/PRUEBAS, independencia de datos y restauración, guardado fuera de la VM y del repositorio en
`C:\Users\ghall\abaco-entrega\demo\demo-abaco-lab.mp4` (7 min 26 s, con voz). El enlace va en la tarea semanal.

Punto de vuelta final de la VM: snapshot de VirtualBox `dia4-final` (tras `dia2-nginx-ok` y `dia3-docker-ok`).

## Límites
- Solo laboratorio local: sin HTTPS, sin dominio real y sin acceso desde Internet; los nombres `*.abaco.test`
  solo existen en el `hosts` del PC.
- Copia manual y puntual, sin automatizar ni rotar (rsnapshot o cron quedan como ampliación). Para copiar el
  volumen, DEV se para unos segundos.
- Sin monitorización ni alertas: los fallos se detectan mirando.
- La configuración de Nginx se copia a mano desde `nginx/`; nada comprueba que el sitio responde tras un cambio.
- `compose stop` de DEV tarda unos 10 s (el proceso del contenedor ignora `SIGTERM`); no corregido.
- Los snapshots de VirtualBox son un punto de vuelta, no una copia: viven en el mismo disco.

## Fuentes consultadas
Documentación oficial enlazada en el plan de formación:
- Ubuntu Server: [instalación básica](https://ubuntu.com/server/docs/tutorial/basic-installation/), [OpenSSH](https://ubuntu.com/server/docs/how-to/security/openssh-server/), [cortafuegos (UFW)](https://ubuntu.com/server/docs/how-to/security/firewalls/), [instalar Nginx](https://ubuntu.com/server/docs/how-to/web-services/install-nginx/), [copias con scripts de shell](https://ubuntu.com/server/docs/how-to/backups/back-up-using-shell-scripts/)
- VirtualBox: [modos de red](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/networkingdetails.html)
- Nginx: [guía para principiantes](https://nginx.org/en/docs/beginners_guide.html)
- Docker: [instalar en Ubuntu](https://docs.docker.com/engine/install/ubuntu/), [Dockerfile](https://docs.docker.com/build/concepts/dockerfile/), [modelo de Compose](https://docs.docker.com/compose/intro/compose-application-model/), [Compose: primeros pasos](https://docs.docker.com/compose/gettingstarted/), [volúmenes](https://docs.docker.com/engine/storage/volumes/) y [copia y restauración de volúmenes](https://docs.docker.com/engine/storage/volumes/#back-up-restore-or-migrate-data-volumes)
- Ayuda integrada en la VM: `man` y `--help` de `sshd_config`, `ufw`, `tar`, `ss` y `journalctl`

## Ayuda recibida
- **IA (Claude, mediante Claude Code)**: me guio paso a paso con explicaciones breves de cada comando, me ayudó
  a interpretar errores y salidas, comprobó el estado de la VM por SSH (sin `sudo`) y redactó la parte técnica de
  la documentación (comandos, tablas y evidencias) a partir de mis capturas. Los comandos los ejecuté yo.
  Las secciones "Qué he aprendido", las dificultades y la causa raíz y prevención del RCA son mías.

## Pendientes
- Opcional, no hecho: fallo de permisos o de Compose, `init: true` en Compose, automatizar copias.

## Estructura
- `documentacion/`: `instalacion.md`, `despliegue.md`, `backup-restore.md`, `incidencia-rca.md`
- `nginx/`, `docker/`: configuraciones, Dockerfile, Compose, `.env.example` y web ficticia
- `evidencias/diaN/`: salidas y capturas de cada día (explicadas en cada documento)
- `notas-lecciones.md`: lecciones de cada paso, errores y hallazgos
