# abaco-lab

Laboratorio de la formación en servidores de Abaco (13-16 de octubre de 2026): Ubuntu Server 24.04, SSH,
Nginx y Docker Compose sobre una VM de VirtualBox.

## Estado
| Día | Tema | Estado |
|---|---|---|
| Mar 13 | Instalar Ubuntu, SSH con clave y UFW | ✅ Hecho ([instalacion.md](documentacion/instalacion.md)) |
| Mié 14 | Nginx: dos sitios y proxy inverso | ✅ Hecho ([despliegue.md](documentacion/despliegue.md)) · SSH reforzado (sin contraseña ni root) · snapshot `dia2-nginx-ok` |
| Jue 15 | Docker Compose: DEV y PRUEBAS separados | ✅ Hecho ([despliegue.md](documentacion/despliegue.md), parte 2) · Docker oficial con `sudo docker` · Nginx delante de los contenedores · snapshot `dia3-docker-ok` |
| Vie 16 | Copias, restauración, diagnóstico y RCA | 🔄 En curso · ✅ Revisión de huecos (config de PRUEBAS, DNS) · ✅ Línea base del sistema ([incidencia-rca.md](documentacion/incidencia-rca.md) §1) · ✅ Copia, restauración y validación ([backup-restore.md](documentacion/backup-restore.md)) · ✅ Fallos A (Nginx parado) y B (502) · 🔄 RCA (falta causa raíz y prevención) · ⏳ README final, reinicio de comprobación y demo |

## Mapa
```
[ PC Windows 192.168.56.20 ] --(solo-anfitrión)--> [ VM abacolab 192.168.56.102 ]
                                                        |
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

## Sitios
| URL (desde el PC, con `hosts`) | Qué sirve |
|---|---|
| `http://dev.abaco.test` | Nginx → `127.0.0.1:3001` → contenedor `abaco-dev-web-1` (imagen `abaco-web:dev-2`, volumen `abaco-dev_datos`) |
| `http://pruebas.abaco.test` | Nginx → `127.0.0.1:3002` → contenedor `abaco-pruebas-web-1` (imagen `abaco-web:pruebas-1`, volumen `abaco-pruebas_datos`) |

Hasta el día 2 los sitios eran archivos en `/var/www/` y `/app/` iba a una aplicación de Python en el 8080;
desde el día 3 los sirven los contenedores.

## Copias de seguridad
Copia de la configuración y del volumen `abaco-dev_datos`, restaurada y validada el 16 oct
([backup-restore.md](documentacion/backup-restore.md)). Se conserva fuera de la VM y del repositorio, en el PC:
`C:\Users\ghall\abaco-entrega\backups\` (con `SHA256SUMS`).

## Estructura
- `documentacion/`: `instalacion.md`, `despliegue.md`, `backup-restore.md`, `incidencia-rca.md`
- `nginx/`, `docker/`: configuraciones
- `evidencias/diaN/`: salidas y capturas de cada día
- `notas-lecciones.md`: lecciones de cada paso, base para la sección "Qué he aprendido"

La guía completa para repetir el laboratorio (requisitos, pasos de arranque, pruebas, límites, fuentes y ayuda
recibida) se completa al final del viernes 16.
