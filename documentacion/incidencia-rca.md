# Incidencias y RCA (día 4)

## 1. Observación del sistema: línea base (viernes 16, 15:27)
Estado del servidor antes de provocar fallos, para comparar con él durante el diagnóstico.

```bash
systemctl --failed
systemctl status nginx docker --no-pager
uptime ; free -h ; df -h /
top -b -n 1 | head -15
sudo ss -lntp
sudo journalctl -p warning -b --no-pager | tail -20
sudo docker compose -p abaco-dev logs --tail 10
sudo docker compose -p abaco-pruebas logs --tail 10
```

| Área | Comando | Valor | Valoración |
|---|---|---|---|
| Servicios rotos | `systemctl --failed` | `0 loaded units listed` | ✅ Bien |
| Nginx | `systemctl status nginx` | `active (running)`, `enabled`; 1 master + 2 workers; 2,7 MB de RAM; último `reload` con `status=0/SUCCESS` | ✅ Bien |
| Docker | `systemctl status docker` | `active (running)`, `enabled`; 41,1 MB de RAM; un `docker-proxy` por puerto publicado (`127.0.0.1:3001 → 172.18.0.2:8080`) | ✅ Bien |
| Carga | `uptime`, `top` | load average `0.00, 0.00, 0.00`; CPU 95,2 % libre (`id`); 127 tareas, 0 zombies | ✅ Bien (2 vCPU, muy por debajo de 2) |
| RAM | `free -h` | 3,8 GiB total, 533 MiB usados, **3,3 GiB disponibles**; swap 0 B usado | ✅ Bien |
| Disco | `df -h /` | 37 GB, 7,0 GB usados (**21 %**; 19 % el jueves antes de Docker) | ✅ Bien |
| Puertos | `sudo ss -lntp` | 22 `sshd`/`systemd` y 80 `nginx` en todas las interfaces; 3001/3002 `docker-proxy` solo en `127.0.0.1`; 53 `systemd-resolve` solo en localhost | ✅ Bien (lo esperado) |
| Contenedores | `docker compose … logs` | Peticiones `GET / HTTP/1.0` con `200`; origen `172.18.0.1` (DEV) y `172.19.0.1` (PRUEBAS) | ✅ Bien |
| Avisos del sistema | `journalctl -p warning -b` | Ver tabla siguiente | ⚠️ Revisado: nada que corregir |

Avisos de `journalctl -p warning -b`:

| Aviso | Significado | Valoración |
|---|---|---|
| `dbus-daemon: Unknown group "power"` | Una regla de D-Bus menciona un grupo que no existe en Ubuntu Server | Inofensivo, conocido |
| `kauditd_printk_skb: 94 callbacks suppressed` | El kernel limitó mensajes de auditoría repetidos (coinciden con la instalación de Docker) | Inofensivo |
| `workqueue: … hogged CPU for >10000us` | Tareas del kernel que tardaron; aparecen al reanudar la VM tras una pausa | Normal en una VM; vigilar si se repite con la VM en uso |
| `sudo: samiabaco : a password is required ; COMMAND=/usr/bin/true` | Comprobación sin contraseña (`sudo -n true`) lanzada durante las pruebas del jueves | Esperado: confirma que `sudo` exige contraseña |
| `[UFW BLOCK] … SRC=192.168.56.20 DST=192.168.56.102 … DPT=3001` (y `3002`) | UFW descartó las conexiones del PC a 3001/3002 (la prueba de seguridad del jueves, 15:47-15:48) | ✅ Evidencia de que UFW bloquea esos puertos |

**Necesita atención: el reloj y `uptime`.** El sistema arrancó el 15 oct a las 12:36 (lo dicen el `journal` y
`systemctl status`), pero `uptime` marca 15 h 12 min y `uptime -s` da `2026-10-16 00:14`. La VM estuvo pausada
mientras el PC estaba suspendido; `uptime` no cuenta ese tiempo y, al reanudar, la hora se corrigió
(`systemd-resolved: Clock change detected` el 15 oct a las 14:22 y 20:06 y el 16 oct a las 13:19). `timedatectl`:
`System clock synchronized: yes`, `NTP service: active`. No es un fallo, pero al comparar horas de logs hay que
tener en cuenta esas pausas, y `uptime` no sirve para saber cuándo arrancó la máquina en este laboratorio.

Evidencias: `evidencias/dia4/03-servicios-failed-status.png` · `04-uptime-free-df.png` · `05-top.png` ·
`06-ss-lntp-procesos.png` · `07-journalctl-warnings.png` · `08-logs-compose.png`.
