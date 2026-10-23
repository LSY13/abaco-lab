# Incidencias y RCA (día 4)

| Sección | Estado (16 oct) |
|---|---|
| 1. Observación del sistema (línea base) | ✅ Hecha |
| 2. Fallo A: Nginx parado | ✅ Hecho |
| 3. Fallo B: proxy de DEV a un puerto sin servicio (502) | ✅ Hecho |
| 4. RCA completo de una incidencia | Ver §4 |
| 5. Reinicio de comprobación final | ✅ Hecho |

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

## 2. Fallo A: Nginx parado (viernes 16, 17:15)
Fallo provocado a propósito con `sudo systemctl stop nginx` y diagnosticado como si no se conociera la causa,
eslabón a eslabón y comparando con la línea base (§1). SSH no se toca.

```bash
curl.exe -s -o NUL -w "%{http_code}\n" http://dev.abaco.test       # PC: antes → 200
sudo systemctl stop nginx                                          # VM: provocar el fallo
curl.exe -m 5 -I http://dev.abaco.test                             # PC: síntoma
systemctl status nginx --no-pager                                  # VM: diagnóstico
sudo ss -lntp | grep ':80 '
sudo journalctl -u nginx --since "15 min ago" --no-pager
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3001     # VM: aislar el eslabón
sudo systemctl start nginx                                         # VM: corrección
systemctl is-active nginx
sudo ss -lntp | grep ':80 '
curl.exe -s -o NUL -w "%{http_code}\n" http://dev.abaco.test       # PC: verificación
curl.exe -s -o NUL -w "%{http_code}\n" http://pruebas.abaco.test
```

| Fase | Evidencia | Lectura |
|---|---|---|
| Antes | `curl.exe` → `200` | Punto de partida correcto |
| Síntoma (PC) | `curl: (7) Failed to connect to dev.abaco.test:80 after 2018 ms: Could not connect to server`; navegador: `ERR_CONNECTION_REFUSED` ("ha rechazado la conexión") | Conexión **rechazada**, no *timeout*: el paquete llega a la VM y UFW deja pasar el 80, pero nadie escucha |
| Servicio | `systemctl status nginx` → `inactive (dead) since Fri 2026-10-16 17:15:18 CEST`; `enabled`; `Main PID: 10377 (code=exited, status=0/SUCCESS)`; `ExecStop=… --stop --retry QUIT/5` | Parada ordenada (código 0), no un fallo del programa (sería `failed` con otro código). Sigue `enabled`: arrancaría al reiniciar |
| Puerto | `sudo ss -lntp \| grep ':80 '` → sin salida | En la línea base `nginx` escuchaba en `0.0.0.0:80` y `[::]:80`; ahora nadie |
| Log | `journalctl -u nginx` → `17:15:18 Stopping nginx.service…` / `Deactivated successfully.` / `Stopped nginx.service…` | Dice **cuándo** se paró y que fue una parada pedida, no una caída |
| Aislar | `curl http://127.0.0.1:3001` → `200` | El contenedor de DEV funciona: el eslabón roto es **solo Nginx** |
| Hipótesis | — | Nginx está parado y nada escucha en el 80 |
| Corrección | `sudo systemctl start nginx` → `systemctl is-active nginx` → `active` | — |
| Verificación | `ss` → `nginx` en `0.0.0.0:80` y `[::]:80` (PIDs nuevos 17220-17222); PC: `dev` → `200`, `pruebas` → `200` | Vuelta al estado inicial |

En Windows una conexión rechazada no falla al instante: `curl` tardó 2018 ms porque Windows reintenta el SYN
tras recibir el rechazo (RST) antes de rendirse. Es distinto del *timeout* del jueves contra el 3001 (UFW
descarta el paquete y no llega respuesta hasta agotar `-m 5`); el navegador lo deja claro con
`ERR_CONNECTION_REFUSED`.

Evidencias: `evidencias/dia4/18-curl-antes-y-nginx-parado.png` · `19-navegador-connection-refused.png` ·
`20-diagnostico-status-ss-journal-curl3001.png` · `21a-start-nginx-active-ss.png` · `21b-curl-dev-pruebas-200.png`.

## 3. Fallo B: proxy de DEV a un puerto sin servicio (viernes 16, 17:32)
Fallo provocado cambiando en el sitio de DEV el destino del proxy de `127.0.0.1:3001` (el contenedor) a
`127.0.0.1:3009` (donde no escucha nadie). Antes se comprobó que `/etc/nginx/sites-available/dev.abaco.test` era
idéntico a la copia del repositorio (`~/abaco-lab/nginx/dev.abaco.test`), que sirve de original para restaurar.

```bash
sudo sed -i 's/127.0.0.1:3001/127.0.0.1:3009/' /etc/nginx/sites-available/dev.abaco.test   # provocar
grep -n proxy_pass /etc/nginx/sites-available/dev.abaco.test
sudo nginx -t
sudo systemctl reload nginx
curl.exe -I http://dev.abaco.test                                            # PC: síntoma
curl.exe -s -o NUL -w "%{http_code}\n" http://pruebas.abaco.test
tail -n 3 /var/log/nginx/dev.error.log                                       # VM: diagnóstico
sudo ss -lntp | grep -E ':3001|:3009'
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3001
diff ~/abaco-lab/nginx/dev.abaco.test /etc/nginx/sites-available/dev.abaco.test
sudo cp ~/abaco-lab/nginx/dev.abaco.test /etc/nginx/sites-available/         # corrección
sudo nginx -t
sudo systemctl reload nginx
diff ~/abaco-lab/nginx/dev.abaco.test /etc/nginx/sites-available/dev.abaco.test && echo IDENTICO
curl.exe -s -o NUL -w "%{http_code}\n" http://dev.abaco.test                 # PC: verificación
curl.exe -s -o NUL -w "%{http_code}\n" http://pruebas.abaco.test
```

| Fase | Evidencia | Lectura |
|---|---|---|
| Cambio | `grep` → `13: proxy_pass http://127.0.0.1:3009/;` | El destino del proxy apunta a un puerto vacío |
| Validación | `nginx -t` → `syntax is ok` / `test is successful` | **`nginx -t` solo valida la sintaxis**: un puerto equivocado le parece correcto |
| Síntoma (PC) | `HTTP/1.1 502 Bad Gateway`, `Server: nginx/1.24.0 (Ubuntu)`, `Date: … 15:32:25 GMT`; navegador: página "502 Bad Gateway" | **Hay respuesta y la da Nginx**: Nginx funciona, falla lo de detrás (al revés que el fallo A) |
| Alcance | `pruebas.abaco.test` → `200` | Solo afecta a DEV |
| Log de errores | `2026/10/16 17:32:25 [error] … connect() failed (111: Connection refused) while connecting to upstream, client: 192.168.56.20, server: dev.abaco.test, request: "HEAD / HTTP/1.1", upstream: "http://127.0.0.1:3009/"` (y otra a las 17:32:47, la del navegador) | El log dice el **puerto exacto** al que intenta ir y que allí nadie contesta (111 = rechazada) |
| Log de accesos | `dev.access.log` → `17:32:25 "HEAD /" 502` · `17:32:47 "GET /" 502` · `17:36:41 "GET /" 200` | Cronología de la caída y de la vuelta |
| Puertos | `ss` → solo `127.0.0.1:3001` (`docker-proxy`); nada en 3009 | Confirma que el 3009 está vacío |
| Aislar | `curl http://127.0.0.1:3001` → `200` | La aplicación está bien; falla **a dónde la manda Nginx** |
| Comparar con el original | `diff` → líneas 2 (comentario) y 13 (`proxy_pass`): `3001` frente a `3009` | Localiza el cambio exacto |
| Hipótesis | — | `proxy_pass` de DEV apunta a un puerto sin servicio |
| Corrección | Restaurar el original del repo (`cp`) → `nginx -t` OK → `reload` → `diff` → `IDENTICO` | — |
| Verificación | PC: `dev` → `200`, `pruebas` → `200` | Vuelta al estado inicial |

Notas:
- `sed` cambió también el comentario de la línea 2, que contenía el mismo texto. El `diff` con el original lo
  mostró: una sustitución automática puede tocar más de lo que se quería.
- La cabecera `Date` de HTTP va en GMT (15:32:25) y los logs de Nginx en hora local, CEST (17:32:25): misma hora
  con 2 h de diferencia. Hay que tenerlo en cuenta al cruzar evidencias.
- La primera línea de `dev.error.log` (14 oct, `/app/` → `127.0.0.1:8080`) es del día 2, de antes de arrancar la
  aplicación de Python: el mismo tipo de error.

Evidencias: `evidencias/dia4/22-sed-3009-nginx-t-ok-reload.png` · `23-curl-502-pruebas-200.png` ·
`24-navegador-502.png` · `25-error-log-ss-curl3001-diff.png` · `26a-restaurar-original-nginx-t-identico.png` ·
`26b-curl-dev-pruebas-200.png`.

## 4. RCA: 502 en dev.abaco.test (16 oct 2026)
### Resumen
Entre las 17:32 y las 17:36 del 16 oct `http://dev.abaco.test` respondió `502 Bad Gateway`: Nginx enviaba las
peticiones a `127.0.0.1:3009`, donde no hay ningún servicio. Se resolvió restaurando la configuración original.
(Incidencia provocada a propósito en el laboratorio.)

### Impacto
| | |
|---|---|
| Servicio afectado | DEV (`dev.abaco.test`); PRUEBAS sin afectar (`200`) |
| Duración | ~4 min (primer 502 registrado 17:32:25 → primer 200 17:36:41) |
| Peticiones fallidas | 2 (`dev.access.log`: `HEAD /` y `GET /`, las dos de 192.168.56.20) |
| Datos | Sin pérdida: el contenedor y su volumen no se tocaron |

### Cronología (CEST)
| Hora | Hecho | Fuente |
|---|---|---|
| ~17:31 | Cambio de `proxy_pass` a `:3009`, `nginx -t` OK y `reload` | Captura 22 |
| 17:32:25 | Primer 502 (`curl -I` desde el PC) | `dev.access.log`, `dev.error.log` |
| 17:32:47 | Segundo 502 (navegador) | `dev.access.log`, `dev.error.log` |
| 17:3x | Diagnóstico: `error.log` → upstream `:3009`; `ss`; `curl :3001` → 200; `diff` | Captura 25 |
| ~17:36 | Restauración del original, `nginx -t`, `reload` | Captura 26a |
| 17:36:41 | Primer 200 desde el PC | `dev.access.log` |

### Detección
Por el síntoma desde el cliente (`502` en `curl` y en el navegador). No hay monitorización que avise.

### Evidencias
`dev.error.log` (`connect() failed (111: Connection refused) … upstream: "http://127.0.0.1:3009/"`),
`dev.access.log`, `ss -lntp`, `curl` a `127.0.0.1:3001` y `diff` con el original (ver §3).

### Causa raíz
**Hechos comprobados:** el bloque `dev.abaco.test` tenía `proxy_pass http://127.0.0.1:3009/`. En el 3009 no escucha
nada (`ss -lntp`), y Nginx lo registra en `dev.error.log` como `connect() failed (111: Connection refused) …
upstream: "http://127.0.0.1:3009/"`. El contenedor de DEV seguía bien en el 3001 (`curl 127.0.0.1:3001` → 200). Al
restaurar el `proxy_pass` original volvió el 200.

**Causa:** un cambio de configuración apuntó el proxy a un puerto sin servicio. Nginx funcionaba, pero no tenía a
quién pasar la petición, y por eso devolvía 502 (Bad Gateway: el fallo está detrás de Nginx, no en Nginx).

**Por qué no se detectó antes de aplicar:** `nginx -t` solo comprueba que la sintaxis es correcta. No comprueba que
el destino del `proxy_pass` exista ni responda. El cambio pasó la validación y se aplicó con `reload`.

### Corrección aplicada
Restaurar `/etc/nginx/sites-available/dev.abaco.test` desde la copia del repositorio, `sudo nginx -t`,
`sudo systemctl reload nginx` y comprobar `200` en DEV y PRUEBAS.

### Prevención
- Antes del `reload`, comprobar que el puerto de destino tiene servicio (`ss -ltn` o `curl 127.0.0.1:<puerto>` desde
  la VM).
- Después del `reload`, comprobar el sitio desde el PC: código 200 **y** marcador (con `comprobar-sitio.ps1`).
- Guardar una copia del bloque antes de cambiarlo (o tenerlo en el repo) para poder volver atrás rápido, como se hizo
  aquí con `diff` y restauración.
- Pendiente de comprobar: no hay monitorización que avise sola. El 502 se detectó solo porque alguien hizo la
  petición.

## 5. Reinicio de comprobación final (viernes 16, 17:46)
Tras los dos fallos se reinició la VM (`sudo reboot`) para comprobar que todo vuelve solo, sin tocar nada.

| Comprobación | Comando | Resultado |
|---|---|---|
| Arranque | `uptime -s` | `2026-10-16 17:46:04` (reinicio recién hecho) |
| SSH con clave | `ssh samiabaco@192.168.56.102` (PC) | Entra sin contraseña; `Ubuntu 24.04.5 LTS`, kernel `6.8.0-147-generic` |
| Root bloqueado | `ssh root@192.168.56.102` (PC) | `Permission denied (publickey)` |
| Servicios | `systemctl is-active nginx docker ssh` | `active` · `active` · `active` |
| Contenedores | `sudo docker ps` | `abaco-dev-web-1` y `abaco-pruebas-web-1` `Up About a minute`, en `127.0.0.1:3001` y `127.0.0.1:3002` (`restart: unless-stopped`) |
| Datos | `sudo docker exec … cat /datos/prueba.txt` | `dato DEV` y `dato PRUEBAS`: sobreviven al reinicio y siguen separados |
| Cortafuegos | `sudo ufw status` | `active`; 22/tcp y 80/tcp `ALLOW` desde `192.168.56.20` |
| Sitios (PC) | `curl.exe … http://dev.abaco.test` y `http://pruebas.abaco.test` | `200` y `200` |

Al entrar, Ubuntu avisa de `New release '26.04.1 LTS' available`: no se actualiza, el laboratorio se hace en
24.04 LTS como pide el plan. Uso de disco: 19,5 % de 36,07 GB; memoria 7 %.

Evidencias: `evidencias/dia4/27a-reboot-ssh-con-clave.png` · `27b-ssh-root-rechazado.png` ·
`28-tras-reinicio-servicios-contenedores-datos-ufw.png` · `29-tras-reinicio-curl-dev-pruebas-200.png`.
