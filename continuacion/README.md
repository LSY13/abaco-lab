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
| PC → Nginx | `curl.exe -i http://ensayo.abaco.test` (o con `--resolve`) | PC (PowerShell) | |
| Nombre → IP | `Select-String abaco C:\Windows\System32\drivers\etc\hosts` | PC (PowerShell) | |
| Nginx | `sudo nginx -t` y `/var/log/nginx/ensayo.access.log` | VM | |
| Nginx → contenedor | `curl -i http://127.0.0.1:3011/` | VM | |
| Contenedor | `sudo docker compose -p abaco-ensayo ps` | VM | |
| Volumen | `sudo docker exec abaco-ensayo-web-1 cat /datos/prueba.txt` | Dentro del contenedor | |
| Aislamiento | `curl.exe --max-time 5 http://192.168.56.102:3011/` | PC (PowerShell) | |

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
