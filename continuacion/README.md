# Continuación del laboratorio (semana del 19 oct 2026)

Segunda fase del laboratorio: un entorno nuevo **ENSAYO** junto a DEV y PRUEBAS, tres casos de diagnóstico y una
mejora para comprobar que un sitio es el correcto. Parte del commit `428b07f` (estado final del 16 oct).

## 1. Referencia antes de cambiar nada (lunes 19, 12:32 CEST)
| Comprobación | Resultado |
|---|---|
| VM | `abacolab`, accesible por SSH con clave (`samiabaco@192.168.56.102`) |
| Servicios | `ssh`, `nginx` y `docker`: `active` |
| Nginx | `nginx -t` correcto; `sites-enabled`: `default`, `dev.abaco.test`, `pruebas.abaco.test` |
| Arranque | La VM venía de un estado guardado: `uptime -s` da 11:28 y los contenedores marcan `Up 2 days`; no hubo reinicio desde el viernes |

| Elemento | DEV | PRUEBAS |
|---|---|---|
| Sitio | `dev.abaco.test` | `pruebas.abaco.test` |
| Proyecto / contenedor | `abaco-dev` / `abaco-dev-web-1` | `abaco-pruebas` / `abaco-pruebas-web-1` |
| Imagen | `abaco-web:dev-2` | `abaco-web:pruebas-1` |
| Puerto | `127.0.0.1:3001` → `8080` | `127.0.0.1:3002` → `8080` |
| Página desde el PC | `200 OK` · `<h1>Abaco DEV</h1>` | `200 OK` · `<h1>Abaco PRUEBAS</h1>` |
| Volumen y dato | `abaco-dev_datos` → `/datos/prueba.txt` = `dato DEV` | `abaco-pruebas_datos` → `/datos/prueba.txt` = `dato PRUEBAS` |

Otros recursos que existen y no se tocan: volumen `abaco-dev_restore` (restauración del 16 oct) y el sitio
`default` de Nginx.

**Archivos a proteger**
- Repositorio: `docker/dev/`, `docker/pruebas/`, `nginx/dev.abaco.test`, `nginx/pruebas.abaco.test`.
- VM: `/etc/nginx/sites-available/{default,dev.abaco.test,pruebas.abaco.test}` y sus enlaces en `sites-enabled`,
  `~/abaco-lab/docker/dev/.env`, `~/abaco-lab/docker/pruebas/.env`.
- Volúmenes: `abaco-dev_datos`, `abaco-pruebas_datos`, `abaco-dev_restore`.

Evidencias: [01](evidencias/01-linea-base-sistema-nginx.png) sistema y Nginx ·
[02](evidencias/02-linea-base-docker.png) proyectos, contenedores, volúmenes y datos ·
[03](evidencias/03-linea-base-curl-pc.png) páginas vistas desde el PC.

**Nombres de ENSAYO libres** (antes de crear nada)
| Qué | Comprobación | Resultado |
|---|---|---|
| Puertos 3011 (ENSAYO) y 3012 (caso C) | `ss -ltn \| grep :30` | Solo escuchan `127.0.0.1:3001` y `127.0.0.1:3002` |
| Proyectos `abaco-ensayo` y `abaco-comprobacion` | `sudo docker compose ls -a` (incluye parados) | Solo `abaco-dev` y `abaco-pruebas` |
| Imagen `abaco-web:ensayo-1` | `sudo docker images abaco-web` | Solo `dev-1` (sin uso, del 15 oct), `dev-2` y `pruebas-1` |
| Sitio `ensayo.abaco.test` | `sudo grep -ri ensayo /etc/nginx/` | Sin resultados |
| Carpeta `docker/ensayo/` | `ls ~/abaco-lab/docker/` | Solo `dev` y `pruebas` |
| Nombre en el PC | `hosts` de Windows | Solo `dev.abaco.test` y `pruebas.abaco.test` |

Se mantienen los nombres del PDF. Evidencia: [04](evidencias/04-ensayo-nombres-libres.png).

## 2. Mapa: recorrido de una petición
```
 PC Windows 192.168.56.20                 VM abacolab 192.168.56.102
 ┌────────────────────────┐   HTTP :80   ┌───────────────────────────────────────────────────────────────┐
 │ navegador / curl.exe   │ ───────────► │ Nginx :80 ── elige el sitio por el nombre pedido (Host)       │
 │ hosts: *.abaco.test →  │  (red solo-  │   ├─ dev.abaco.test     → 127.0.0.1:3001 → contenedor :8080 → volumen abaco-dev_datos     (/datos)
 │        192.168.56.102  │  anfitrión)  │   ├─ pruebas.abaco.test → 127.0.0.1:3002 → contenedor :8080 → volumen abaco-pruebas_datos (/datos)
 └────────────────────────┘              │   ├─ ensayo.abaco.test  → 127.0.0.1:3011 → contenedor :8080 → volumen abaco-ensayo_datos  (/datos)  [nuevo]
                                         │   └─ default  (sitio de la instalación de Nginx, activo)        │
                                         └───────────────────────────────────────────────────────────────┘
```
Los puertos 30xx solo escuchan en `127.0.0.1` de la VM: desde el PC solo se entra por Nginx (80).

| Tramo | Comprobación | Dónde se ejecuta | Qué demuestra si sale bien |
|---|---|---|---|
| PC → Nginx | `curl.exe -i http://ensayo.abaco.test` (o con `--resolve`) | PC (PowerShell) | Desde el PC se llega a Nginx por nombre y contesta el sitio de ENSAYO: código 200 **y** el marcador `ABACO ENSAYO ENTREGA A`. |
| Nombre → IP | `Select-String abaco C:\Windows\System32\drivers\etc\hosts` | PC (PowerShell) | El PC traduce `ensayo.abaco.test` a la IP de la VM (192.168.56.102), así que la petición va a mi VM y no a otro equipo. |
| Nginx | `sudo nginx -t` y `/var/log/nginx/ensayo.access.log` | VM | La configuración de Nginx es válida, y la petición la atendió el bloque de ENSAYO (aparece en su propio log, no en el del sitio por defecto). |
| Nginx → contenedor | `curl -i http://127.0.0.1:3011/` | VM | El contenedor responde en el puerto al que Nginx reenvía (`proxy_pass`); si esto falla, Nginx daría 502. |
| Contenedor | `sudo docker compose -p abaco-ensayo ps` | VM | El contenedor de ENSAYO está en marcha (`Up`) y publica `127.0.0.1:3011->8080`, solo en local. |
| Volumen | `sudo docker exec abaco-ensayo-web-1 cat /datos/prueba.txt` | Dentro del contenedor | El volumen `abaco-ensayo_datos` está montado en `/datos` y conserva el dato (`dato ENSAYO`). |
| Aislamiento | `curl.exe --max-time 5 http://192.168.56.102:3011/` | PC (PowerShell) | Aquí "salir bien" es **no** tener respuesta (timeout): el puerto 3011 no es accesible desde fuera y solo se entra por Nginx. |

## 3. ENSAYO
### Punto de vuelta antes de cambiar Nginx
| Qué | Dónde | Comprobación |
|---|---|---|
| Copia de `/etc/nginx` (`sudo tar -czf ~/nginx-antes-ensayo.tar.gz -C /etc nginx`) | VM `~/nginx-antes-ensayo.tar.gz` y PC `C:\Users\ghall\abaco-entrega\backups\continuacion\` (fuera de Git) | SHA-256 `e77110da13830e7e5a8ad56866c7b836ee8be9d6940823a8187cf7eaa30f85ed` igual en VM y PC; contiene `default`, `dev.abaco.test` y `pruebas.abaco.test` en `sites-available` y sus enlaces en `sites-enabled` |
| Snapshot `continuacion-pre-ensayo` | VirtualBox, hijo de `dia4-final` | `VBoxManage snapshot abaco-lab list` lo marca como actual (`*`) |

Evidencias: [05a](evidencias/05a-copia-nginx-vm-hash.png) · [05b](evidencias/05b-copia-nginx-pc-hash.png) ·
[06](evidencias/06-snapshot-continuacion-pre-ensayo.png).

### Archivos del entorno
| Archivo | Base | Cambios respecto a DEV |
|---|---|---|
| `docker/ensayo/Dockerfile` | `docker/dev/Dockerfile` | Ninguno (idéntico a DEV y PRUEBAS) |
| `docker/ensayo/compose.yaml` | `docker/dev/compose.yaml` | Solo el comentario (`-p abaco-ensayo`); mismo patrón `${TAG:?…}`, `127.0.0.1:${PUERTO}:8080` y volumen `datos:/datos` |
| `docker/ensayo/.env.example` | `docker/dev/.env.example` | `TAG=ensayo-1`, `PUERTO=3011`; sin secretos |
| `docker/ensayo/index.html` | `docker/dev/index.html` | Marcador `ABACO ENSAYO ENTREGA A` |
| `nginx/ensayo.abaco.test` | `nginx/dev.abaco.test` | `server_name ensayo.abaco.test`, logs `ensayo.*.log`, `proxy_pass` a `127.0.0.1:3011` |

### Contenedor y dato (VM, `~/abaco-lab/docker/ensayo/`)
| Paso | Comando | Resultado |
|---|---|---|
| Traer los archivos | `git pull` | `21ebdfd..66ccd87` (fast-forward); sin cambios en `docker/dev`, `docker/pruebas` ni sus bloques de Nginx |
| `.env` local | `cp .env.example .env` | `TAG=ensayo-1`, `PUERTO=3011` (fuera de Git) |
| Validar sin crear nada | `sudo docker compose -p abaco-ensayo config` | `image: abaco-web:ensayo-1`; `host_ip: 127.0.0.1`, `published: "3011"`, `target: 8080`; red `abaco-ensayo_default`; volumen `abaco-ensayo_datos` |
| Construir y arrancar | `sudo docker compose -p abaco-ensayo up -d --build` | Imagen, red, volumen y contenedor `abaco-ensayo-web-1` nuevos |
| Contenedor | `curl -s http://127.0.0.1:3011/ \| grep ABACO` | `<h1>ABACO ENSAYO ENTREGA A</h1>` |
| Estado inicial del volumen | `sudo docker exec abaco-ensayo-web-1 ls -la /datos` | Vacío: el dato no venía de antes |
| Dato propio | `echo "dato ENSAYO" \| sudo docker exec -i abaco-ensayo-web-1 tee /datos/prueba.txt` | `cat /datos/prueba.txt` → `dato ENSAYO` |

Evidencias: [07a](evidencias/07a-git-pull-vm.png) · [07b](evidencias/07b-env-compose-config-ensayo.png) ·
[08](evidencias/08-up-ps-curl-ensayo.png) · [09](evidencias/09-dato-ensayo-volumen.png).

### Nginx y acceso desde el PC
| Paso | Comando | Resultado |
|---|---|---|
| Activar el sitio | `sudo cp ~/abaco-lab/nginx/ensayo.abaco.test /etc/nginx/sites-available/` y `sudo ln -s …/sites-available/ensayo.abaco.test /etc/nginx/sites-enabled/` | Cuatro sitios en `sites-enabled` |
| Validar y aplicar | `sudo nginx -t` → `sudo systemctl reload nginx` | `test is successful`; recarga sin cortar DEV ni PRUEBAS |
| Nginx desde la VM | `curl -s -i -H "Host: ensayo.abaco.test" http://localhost/` | `200` + marcador; registrado en `ensayo.access.log` (`200 244`) |
| Nombre en el PC | Copia `hosts-antes-ensayo` en `abaco-entrega\backups\continuacion\` y línea `192.168.56.102  ensayo.abaco.test` en `hosts` | `diff` con la copia: solo esa línea nueva |
| Desde el PC | `curl.exe -s -i http://ensayo.abaco.test` y navegador | `200` + `ABACO ENSAYO ENTREGA A` |
| Aislamiento | `curl.exe --max-time 5 http://192.168.56.102:3011/` | `Connection timed out`: 3011 solo en `127.0.0.1` y UFW descarta |

### DEV y PRUEBAS siguen igual
| | DEV | PRUEBAS |
|---|---|---|
| Página desde el PC | `200` · `<h1>Abaco DEV</h1>` | `200` · `<h1>Abaco PRUEBAS</h1>` |
| Contenedor | `abaco-web:dev-2`, `127.0.0.1:3001`, `Up 2 days` (no recreado) | `abaco-web:pruebas-1`, `127.0.0.1:3002`, `Up 2 days` |
| Dato | `dato DEV` | `dato PRUEBAS` |

Punto de vuelta con ENSAYO funcionando: snapshot `ensayo-ok`.

Evidencias: [10](evidencias/10-nginx-enlace-ensayo-nginx-t.png) · [11](evidencias/11-reload-curl-host-log-ensayo.png) ·
[12a](evidencias/12a-hosts-pc-ensayo.png) · [12b](evidencias/12b-pc-curl-ensayo-3011-timeout.png) ·
[13](evidencias/13-navegador-ensayo.png) · [14a](evidencias/14a-pc-dev-pruebas-siguen-igual.png) ·
[14b](evidencias/14b-vm-contenedores-datos-siguen-igual.png) · [15](evidencias/15-snapshot-ensayo-ok.png).

## 4. Cómo abrir y comprobar ENSAYO
**Abrir**
- VM: `cd ~/abaco-lab/docker/ensayo`, `.env` copiado de `.env.example` y
  `sudo docker compose -p abaco-ensayo up -d` (sirve en `127.0.0.1:3011`, detrás de Nginx).
- PC: `hosts` con `192.168.56.102  ensayo.abaco.test` y navegador en `http://ensayo.abaco.test`; sin tocar el
  `hosts`, `curl.exe --resolve ensayo.abaco.test:80:192.168.56.102 http://ensayo.abaco.test/`.

**Comprobar** (algo más que un `200`)
- PC, página correcta: `powershell -ExecutionPolicy Bypass -File .\comprobar-sitio.ps1 -Url http://ensayo.abaco.test/ -Marcador "ABACO ENSAYO ENTREGA A"`
  → `RESULTADO: OK`. Ver la [mejora en la bitácora](bitacora.md#mejora--comprobar-que-un-sitio-es-el-correcto-no-solo-que-responde).
- VM, dato propio: `sudo docker exec abaco-ensayo-web-1 cat /datos/prueba.txt` → `dato ENSAYO`.

## 5. Casos investigados
Detalle, pruebas y evidencias en [bitacora.md](bitacora.md).
| Caso | Síntoma | Causa comprobada |
|---|---|---|
| A | `200` sin `ABACO ENSAYO ENTREGA A` al pedir por la IP | Con `Host: 192.168.56.102` ningún `server_name` coincide y contesta el bloque `default_server` (página de Nginx, 615 bytes) |
| B | `falta TAG en .env` al validar | `--env-file caso-b.env` usa solo ese archivo, que no tiene `TAG`; el `.env` no se lee. Ningún contenedor cambió |
| C | Misma página en `127.0.0.1:3012` sin `/datos/prueba.txt` | Otro nombre de proyecto crea su propio volumen vacío (`abaco-comprobacion_datos`); el dato sigue en `abaco-ensayo_datos` |

## 6. Estado
| Comprobación | Estado |
|---|---|
| ENSAYO con su marcador y su dato | ✅ `200` + `ABACO ENSAYO ENTREGA A` y `dato ENSAYO` |
| Casos A, B y C explicados con pruebas | ✅ Pruebas y evidencias 16-33 |
| La mejora distingue correcto de incorrecto | ✅ OK y FALLO, probada desde otra sesión (evidencias 34-35) |
| DEV y PRUEBAS conservan página y datos | ✅ Comprobado tras ENSAYO y tras el caso C |
| `.env` y copias locales fuera de Git | ✅ `caso-b.env`, `caso-c.env` y `.env` ignorados por `*.env` |

Recursos que quedan del caso C, parados y sin borrar: proyecto `abaco-comprobacion` (contenedor
`abaco-comprobacion-web-1` `Exited (137)`), volumen `abaco-comprobacion_datos` (vacío) y red
`abaco-comprobacion_default`.

## 7. Pendientes
- Decidir con el tutor si se borran los recursos que quedan del caso C (§6). No se borraron porque la tarea no lo
  permite.
- No hay monitorización que avise sola: `comprobar-sitio.ps1` se ejecuta a mano (ver límites en la
  [bitácora](bitacora.md)).
