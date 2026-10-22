# Bitácora de la continuación

Casos A, B y C, la mejora, evidencias y fuentes usadas. Cada entrada sigue la plantilla del PDF.

## Caso A · La página no es la esperada
**Fecha:** martes 20 de octubre de 2026

**Qué esperaba y qué ocurrió**
Esperaba la página de ENSAYO con el marcador `ABACO ENSAYO ENTREGA A`. Al pedir la raíz por la IP de la VM
(`curl.exe -v -s -i -o caso-a-1-ip.txt http://192.168.56.102/`, sin cabeceras propias, Ficha A) recibí
`HTTP/1.1 200 OK` con 615 bytes y la página `Welcome to nginx!`, sin el marcador. Síntoma reproducido.

**Dos hipótesis**
1. La petición no ha llegado a mi VM, sino a otro equipo de la red solo-anfitrión que también tiene un servidor
   web en el puerto 80. Puede pasar si el nombre o la IP usados apuntan a ese otro equipo, por ejemplo por un
   `hosts` desactualizado o porque la VM cambió de IP. Si fuera así, `curl -v` mostraría una IP de destino
   distinta de `192.168.56.102`, o la petición no aparecería en ningún log de Nginx de mi VM.
2. Entre mi PC y la VM hay un proxy con caché (o la caché del propio navegador) que tiene guardada una copia
   antigua de la respuesta para esa URL. En lugar de pedirla a mi Nginx, contesta él con la copia guardada.

**Prueba elegida y motivo**
Comparo dos peticiones al mismo destino (la IP de la VM), cambiando solo el nombre que pido: una sin nombre (la
IP tal cual) y otra con `ensayo.abaco.test` mediante `--resolve`.

**Resultado observado**
| | Petición 1 (IP) | Petición 2 (`--resolve`, mismo destino) |
|---|---|---|
| Conexión (`curl -v`) | `192.168.56.102 port 80` | `192.168.56.102 port 80` |
| `Host:` enviado | `192.168.56.102` | `ensayo.abaco.test` |
| Respuesta | `200 OK`, 615 bytes, `Welcome to nginx!` | `200 OK`, 244 bytes, `ABACO ENSAYO ENTREGA A` |
| Cabeceras | `ETag`, `Accept-Ranges`, `Last-Modified: 14 Oct 2026 11:30:41 GMT` | Sin `ETag` ni `Accept-Ranges` |
| Log en la VM (CEST) | `access.log`: `192.168.56.20 … 11:38:08 … 200 615` | `ensayo.access.log`: `192.168.56.20 … 11:38:34 … 200 244` |

- Sin variables de proxy (`Get-ChildItem Env:*proxy*` vacío); con `--noproxy "*"` la petición 1 da lo mismo
  (`200 615`, registrada en `access.log` a las 11:42:28). Ninguna respuesta trae `Via:`, `Age:` ni `X-Cache`.
- `/etc/nginx/sites-enabled/default`: `listen 80 default_server;`, `server_name _;`, `root /var/www/html;`. En
  `/var/www/html/` solo está `index.nginx-debian.html`, 615 bytes, 14 oct 13:30 (instalación de Nginx).

**Qué cambié o descarté**

**Cómo lo verifiqué**
Comparando dos peticiones que solo se diferencian en el nombre pedido, y comprobando en la VM qué log registró
cada una y qué bloque de Nginx tiene `default_server`. La petición que cierra el caso es la 2 (o
`curl.exe -s -i http://ensayo.abaco.test` con el `hosts`): `200` y `ABACO ENSAYO ENTREGA A`. No se cambió ninguna
configuración.

**Qué prevendría**

**Fuente y ayuda recibida**
- R5 · Nginx, selección del sitio por nombre (cómo se elige un `server` y qué pasa si el nombre no coincide).
- R6 · curl, `--resolve` (y `-v`, `--noproxy`).
- Ayuda de IA (Claude): me propuso posibles hipótesis entre las que elegí dos, corrigió la segunda (una caché HTTP
  guarda respuestas, no "direcciones": la caché nombre→IP es la DNS) y me dio los comandos de comparación.

**Siguiente paso**

Evidencias: [16a](evidencias/16a-caso-a-curl-ip.png) · [16b](evidencias/16b-caso-a-curl-resolve-nombre.png) ·
[17](evidencias/17-caso-a-marcador-y-pagina-ip.png) · [18](evidencias/18-caso-a-sin-proxy.png) ·
[19](evidencias/19-caso-a-logs-nginx.png) · [20](evidencias/20-caso-a-default-server.png) · respuestas completas en
[caso-a-1-ip.txt](evidencias/caso-a-1-ip.txt) y [caso-a-2-nombre.txt](evidencias/caso-a-2-nombre.txt).
Nota: en `ensayo.access.log` hay dos peticiones de comprobación hechas por Claude desde la VM (`127.0.0.1`,
`curl/8.5.0`, 19 oct 14:02:38 y 21:03:45) que no forman parte del caso.

## Caso B · No se puede continuar
**Fecha:** miércoles 21 de octubre de 2026

**Qué esperaba y qué ocurrió**
Desde `~/abaco-lab/docker/ensayo/` creé `caso-b.env` solo con `PUERTO=3011` (Ficha B; `.env` y `.env.example`
intactos) y validé con `sudo env -u TAG -u PUERTO docker compose --env-file caso-b.env -p abaco-ensayo config`.
Esperaba ver la configuración resuelta; en su lugar: `error while interpolating services.web.image: required
variable TAG is missing a value: falta TAG en .env`, con código de salida `1`. Síntoma reproducido (dos veces).

**Dos hipótesis**
1. Compose se ha ejecutado desde una carpeta que no es `docker/ensayo/`, así que no ha usado el `.env` de ENSAYO,
   que sí tiene `TAG=ensayo-1`, y se ha quedado sin valor para TAG.
2. El valor de TAG depende del entorno del proceso. El `env -u TAG -u PUERTO` ha quitado cualquier TAG heredado de
   la terminal y, como el archivo elegido no lo tiene, Compose no encuentra ningún valor.

**Prueba elegida y motivo**
Repito exactamente el mismo comando, en la misma carpeta y con el mismo `env -u`, cambiando solo el archivo
elegido (`--env-file .env` en lugar de `--env-file caso-b.env`). Si así funciona, ni la carpeta ni el entorno eran
el problema, porque no han cambiado.

**Resultado observado**
- Quién emite el error: Docker Compose, en la interpolación de variables (`error while interpolating`), antes de
  crear o cambiar recursos. El texto `falta TAG en .env` es el de `${TAG:?falta TAG en .env}` en `compose.yaml`.
- Contenedores: `abaco-ensayo-web-1` con el mismo `Id` (`2b463aca2c1c…`) y `StartedAt`
  (`2026-10-19T11:16:57Z`) antes, entre y después de las dos validaciones fallidas.
- Carpeta: `pwd` = `/home/samiabaco/abaco-lab/docker/ensayo`, con `compose.yaml`, `.env`, `.env.example` y
  `caso-b.env`. Entorno: `env | grep TAG` y `sudo env | grep TAG` sin resultado.
- Mismo comando cambiando solo el archivo (`--env-file .env`): configuración resuelta (`image: abaco-web:ensayo-1`,
  `host_ip: 127.0.0.1`, `published: "3011"`) y código de salida `0`.

**Qué cambié o descarté**

**Cómo lo verifiqué**
Validación normal del proyecto, sin `--env-file` ni `env -u`: `sudo docker compose -p abaco-ensayo config --quiet`
→ sin salida y código `0` (usa el `.env` de la carpeta). `caso-b.env` sigue con solo `PUERTO=3011` y
`abaco-ensayo-web-1` mantiene el mismo `Id` y `StartedAt` que antes del caso: no se creó ni cambió ningún
contenedor. No se editó el Dockerfile, ni DEV/PRUEBAS, ni se subió ningún `.env`.

**Qué prevendría**

**Fuente y ayuda recibida**
- R3 · Docker Compose, variables y archivos `.env` (precedencia: entorno del proceso, después el archivo; con
  `--env-file` se usa ese archivo en lugar de `.env`).
- R4 · Docker Compose, comprobar la configuración (`config` muestra la configuración resuelta sin crear nada).
- Ayuda de IA (Claude): me explicó cómo resuelve Compose las variables y me propuso posibles hipótesis, entre las
  que elegí dos.

**Siguiente paso**

Evidencias: [21](evidencias/21-caso-b-validacion-aislada.png) · [22](evidencias/22-caso-b-carpeta-y-entorno.png) ·
[23](evidencias/23-caso-b-mismo-comando-con-env.png) · [24](evidencias/24-caso-b-validacion-normal.png).

## Caso C · El archivo no aparece
**Fecha:** miércoles 21 de octubre de 2026

**Qué esperaba y qué ocurrió**
Desde `~/abaco-lab/docker/ensayo/` preparé `caso-c.env` (`TAG=ensayo-1`, `PUERTO=3012`). Antes de arrancar comprobé
que la imagen `abaco-web:ensayo-1` existía, que el 3012 estaba libre y que no había ningún proyecto ni volumen
`abaco-comprobacion`. Validé y arranqué con el mismo `compose.yaml`
(`sudo docker compose --env-file caso-c.env -p abaco-comprobacion up -d --no-build`). La página en
`127.0.0.1:3012` es la misma que en ENSAYO (`ABACO ENSAYO ENTREGA A`), pero en su servicio web
`cat /datos/prueba.txt` da `No such file or directory`; en ENSAYO sigue dando `dato ENSAYO`.

**Dos hipótesis**
1. Al arrancar la comprobación con otro nombre de proyecto, Compose ha creado un volumen nuevo y vacío, y lo ha
   montado en `/datos`.
2. Las dos ejecuciones usan el mismo volumen (`abaco-ensayo_datos`), pero en la comprobación está montado en otra
   carpeta distinta de `/datos`, así que al buscar en `/datos/prueba.txt` no lo encuentro aunque el archivo exista.

**Prueba elegida y motivo**
Ejecuto el mismo comando de inspección de montajes para los dos contenedores, cambiando solo el nombre del
contenedor, y comparo el nombre del volumen y la ruta de destino: volúmenes distintos en la misma ruta apoyan la
hipótesis 1; el mismo volumen en rutas distintas, la 2.

**Resultado observado**
- `config` de la comprobación: `image: abaco-web:ensayo-1`, `host_ip: 127.0.0.1`, `published: "3012"`, red
  `abaco-comprobacion_default` y volumen `abaco-comprobacion_datos`.
- El `up` creó `Network abaco-comprobacion_default`, `Volume abaco-comprobacion_datos` y
  `Container abaco-comprobacion-web-1` (sin construir: usó la imagen existente).
- Montajes (mismo `docker inspect -f '{{range .Mounts}}{{.Name}} -> {{.Destination}}{{end}}'`, solo cambia el contenedor):
  `abaco-ensayo-web-1` → `abaco-ensayo_datos -> /datos`; `abaco-comprobacion-web-1` → `abaco-comprobacion_datos -> /datos`.
- Contenido de cada volumen en la VM (`docker volume inspect` → `/var/lib/docker/volumes/<volumen>/_data`):
  `abaco-ensayo_datos` tiene `prueba.txt` (12 bytes, 19 oct 13:21); `abaco-comprobacion_datos` está vacío (creado
  el 21 oct 13:17).

**Qué cambié o descarté**

**Cómo lo verifiqué**
- Acceso al dato correcto sin borrarlo, sin escribir encima ni copiarlo: lectura desde su volumen original en solo
  lectura, con un contenedor temporal: `sudo docker run --rm -v abaco-ensayo_datos:/datos:ro abaco-web:ensayo-1 cat
  /datos/prueba.txt` → `dato ENSAYO`.
- Cierre: `sudo docker compose --env-file caso-c.env -p abaco-comprobacion stop` (solo ese proyecto, sin borrar).
  Recursos que quedan de la comprobación: proyecto `abaco-comprobacion` (`exited(1)`), contenedor
  `abaco-comprobacion-web-1` (`Exited (137)`), volumen `abaco-comprobacion_datos` (vacío) y red
  `abaco-comprobacion_default`.
- Entornos anteriores intactos: `dato DEV`, `dato PRUEBAS` y `dato ENSAYO`; desde el PC `Abaco DEV`,
  `Abaco PRUEBAS` y `ABACO ENSAYO ENTREGA A`; DEV y PRUEBAS siguen `Up 4 days`, ENSAYO `Up 2 days`.

**Qué prevendría**

**Fuente y ayuda recibida**
- R2 · Docker Compose, nombre de proyecto (separa los recursos de cada ejecución).
- R7 · Docker, volúmenes y persistencia (ciclo de vida, montaje y comprobación de los datos).
- R10 · Docker Compose, arrancar y recrear (`up -d --no-build`).
- Ayuda de IA (Claude): me explicó cómo se nombran y montan los volúmenes y me propuso posibles hipótesis, entre
  las que elegí dos.

**Siguiente paso**

Evidencias: [25](evidencias/25-caso-c-estado-inicial.png) · [26](evidencias/26-caso-c-config-comprobacion.png) ·
[27a](evidencias/27a-caso-c-up-ps.png) · [27b](evidencias/27b-caso-c-pagina-y-dato.png) · [28](evidencias/28-caso-c-montajes.png) ·
[29](evidencias/29-caso-c-contenido-volumenes.png) · [30](evidencias/30-caso-c-lectura-solo-lectura.png) ·
[31](evidencias/31-caso-c-stop-recursos.png) · [32](evidencias/32-caso-c-datos-intactos.png) · [33](evidencias/33-caso-c-paginas-intactas.png).

## Mejora · Comprobar que un sitio es el correcto, no solo que responde
**Fecha:** jueves 22 de octubre de 2026

**Qué es:** [`comprobar-sitio.ps1`](comprobar-sitio.ps1), un script manual de solo lectura para el PowerShell del
PC. Hace una petición GET sin proxy y con 5 s de límite, y comprueba el código HTTP **y** el marcador exacto de la
página (distinguiendo mayúsculas). Muestra a qué IP se conectó, el tamaño y el título, y termina en OK (salida 0)
o en FALLO con el motivo (salida 1): `200` sin marcador, sin respuesta (`000`) u otro código.

```powershell
powershell -ExecutionPolicy Bypass -File .\comprobar-sitio.ps1 -Url http://ensayo.abaco.test/ -Marcador "ABACO ENSAYO ENTREGA A"
```
`-ExecutionPolicy Bypass` permite el script solo en esa ejecución, sin cambiar la configuración de Windows.

**Qué problema evita y sobre qué entorno actúa**

**Pruebas** (desde otra sesión de PowerShell: PID 24716; la habitual era la 18604)
| Petición | Código | Tamaño | Título | Marcador | Resultado |
|---|---|---|---|---|---|
| `http://ensayo.abaco.test/` | 200 | 244 | `Abaco ENSAYO` | encontrado | **OK** |
| `http://192.168.56.102/` (caso A) | 200 | 615 | `Welcome to nginx!` | NO encontrado | **FALLO**: 200 pero no es la página esperada |
| `http://dev.abaco.test/` con `"Abaco DEV"` | 200 | 310 | `Abaco DEV` | encontrado | **OK** |
| `http://192.168.56.102:3011/` | 000 | 0 | (sin título) | NO encontrado | **FALLO**: sin respuesta |

Ninguna prueba cambió configuración ni datos: solo peticiones GET.

**Límites**

**Fuente y ayuda recibida**
- R6 · curl (`-w`, `--max-time`, `--noproxy`).
- Ayuda de IA (Claude): escribió el script a partir de lo aprendido en los casos (marcador exacto, `--noproxy`,
  tamaño e IP) y lo probó antes de dármelo; yo lo ejecuté desde otra sesión en los casos bueno y malo.

Evidencias: [34a](evidencias/34a-mejora-otra-sesion-ok-y-fallo.png) ·
[34b](evidencias/34b-mejora-pid-sesion-original.png) · [35](evidencias/35-mejora-dev-ok-y-3011-sin-respuesta.png).
