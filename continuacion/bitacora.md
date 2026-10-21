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
