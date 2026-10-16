# Despliegue · Nginx (día 2) y Docker Compose (día 3)

## Parte 1 · Nginx: dos sitios y proxy inverso (miércoles 14)

> **Nota (16 oct):** esta parte describe el estado del miércoles. El jueves se retiraron `location /app/`, la
> aplicación de Python (`~/app-prueba`) y Nginx dejó de servir `/var/www` (sigue en la VM, sin uso): ahora cada
> sitio entero va a su contenedor (ver Parte 2, §6). Las configuraciones vigentes son las de `nginx/`.

### 1. Objetivo
- Servir dos sitios en la misma VM y la misma IP: `dev.abaco.test` y `pruebas.abaco.test`.
- Preparar un proxy inverso `dev.abaco.test/app/` → `127.0.0.1:8080` (mañana, un contenedor Docker).
- Abrir el puerto 80 solo para el PC del laboratorio.

### 2. Esquema
```
                                 ┌──────────────────── VM abacolab 192.168.56.102 ─────────────────────┐
[ PC 192.168.56.20 ]             │                                                                     │
  navegador ── HTTP :80 ── UFW ──┼─▶ Nginx ── Host: dev.abaco.test     ──▶ /var/www/dev               │
  (hosts: *.abaco.test           │     │    ── Host: pruebas.abaco.test ──▶ /var/www/pruebas           │
   → 192.168.56.102)             │     └─── dev.abaco.test/app/ ──────────▶ app en 127.0.0.1:8080       │
                                 │                                          (no accesible desde fuera)  │
                                 └─────────────────────────────────────────────────────────────────────┘
```

### 3. Instalación y cortafuegos
```bash
sudo apt update
sudo apt install -y nginx
systemctl status nginx --no-pager          # active (running), enabled
curl -I http://localhost                   # HTTP/1.1 200 OK (página por defecto)

sudo ufw allow from 192.168.56.20 to any port 80 proto tcp
sudo ufw status numbered                   # [1] 22/tcp y [2] 80/tcp, ambos solo desde 192.168.56.20
```
- Nginx 1.24.0 (Ubuntu). Un proceso *master* (root, lee la configuración) y dos *workers* (`www-data`, uno por CPU).
- El 8080 **no** se abre: la aplicación solo debe ser accesible a través de Nginx.

### 4. Contenido de los sitios
```bash
sudo mkdir -p /var/www/dev /var/www/pruebas
echo '<h1>Abaco DEV</h1><p>Sitio de desarrollo - dev.abaco.test</p>' | sudo tee /var/www/dev/index.html
echo '<h1>Abaco PRUEBAS</h1><p>Sitio de pruebas - pruebas.abaco.test</p>' | sudo tee /var/www/pruebas/index.html
```
Los archivos quedan `644 root` y las carpetas `755` (umask de root `0022`). Nginx solo necesita leer.

### 5. Configuración de los sitios (server blocks)
Las configuraciones están versionadas en [`nginx/`](../nginx/):

| Archivo en el repo | Ruta en la VM | Qué hace |
|---|---|---|
| [`nginx/dev.abaco.test`](../nginx/dev.abaco.test) | `/etc/nginx/sites-available/dev.abaco.test` | Sitio DEV + proxy `/app/` → `127.0.0.1:8080` |
| [`nginx/pruebas.abaco.test`](../nginx/pruebas.abaco.test) | `/etc/nginx/sites-available/pruebas.abaco.test` | Sitio PRUEBAS |

Directivas clave:
- `listen 80;` y `listen [::]:80;`: escuchar en IPv4 **y** IPv6 (ver problema 1).
- `server_name`: el nombre que distingue un sitio del otro (cabecera `Host` de la petición).
- `root` / `index`: de dónde sale el contenido.
- `access_log` / `error_log` propios de cada sitio, para diagnosticar sin mezclar.
- `try_files $uri $uri/ =404;`: si no existe el archivo, 404 limpio.
- `proxy_pass http://127.0.0.1:8080/;`: la `/` final quita el prefijo `/app/` al reenviar.
- `proxy_set_header Host / X-Real-IP / X-Forwarded-For / X-Forwarded-Proto`: la aplicación recibe el nombre pedido y la IP real del visitante, no la de Nginx.

Instalación en la VM (copiando el contenido de cada archivo del repo):
```bash
sudo tee /etc/nginx/sites-available/dev.abaco.test > /dev/null <<'EOF'
...contenido de nginx/dev.abaco.test...
EOF
# (igual para pruebas.abaco.test)

sudo ln -s /etc/nginx/sites-available/dev.abaco.test     /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/pruebas.abaco.test /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx     # validar y, solo si pasa, aplicar
```
- `sites-available` guarda todos los sitios; `sites-enabled` contiene enlaces a los que están activos.
  Para desactivar un sitio se borra el enlace, no la configuración. No se toca `nginx.conf`.
- El sitio `default` se mantiene: responde a las visitas por IP (`http://192.168.56.102`).

### 6. Resolución de nombres en el PC
`.test` es un dominio reservado para pruebas (RFC 6761): no existe en ningún DNS. Se añade al archivo `hosts`
del PC (PowerShell **como administrador**):
```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n192.168.56.102  dev.abaco.test pruebas.abaco.test"
ping -n 1 dev.abaco.test          # responde 192.168.56.102
```

### 7. Aplicación de prueba detrás del proxy
Mientras no hay Docker, una aplicación mínima con el servidor web de Python, **solo en 127.0.0.1**:
```bash
mkdir -p ~/app-prueba
echo '<!DOCTYPE html><meta charset="utf-8"><h1>Aplicación detrás del proxy</h1><p>Servida por Python en 127.0.0.1:8080</p>' > ~/app-prueba/index.html
cd ~/app-prueba && python3 -m http.server 8080 --bind 127.0.0.1     # primer plano; Ctrl+C para parar
```

### 8. Pruebas
| Prueba | Desde | Comando / URL | Resultado esperado | Resultado |
|---|---|---|---|---|
| Nginx responde | VM | `curl -I http://localhost` | `200 OK` | ✅ |
| Puerto 80 abierto solo al PC | VM | `sudo ufw status numbered` | 22 y 80 desde 192.168.56.20 | ✅ |
| Nginx desde el PC | PC | `curl -I http://192.168.56.102` | `200 OK` | ✅ |
| Sitio DEV | VM | `curl -H "Host: dev.abaco.test" http://localhost` | `Abaco DEV` | ✅ (tras corregir IPv6) |
| Sitio PRUEBAS | VM | `curl -H "Host: pruebas.abaco.test" http://localhost` | `Abaco PRUEBAS` | ✅ (tras corregir IPv6) |
| DEV en el navegador | PC | `http://dev.abaco.test` | `Abaco DEV` | ✅ |
| PRUEBAS en el navegador | PC | `http://pruebas.abaco.test` | `Abaco PRUEBAS` | ✅ |
| Proxy sin aplicación | VM | `curl -i -H "Host: dev.abaco.test" http://localhost/app/` | `502 Bad Gateway` | ✅ (esperado) |
| Proxy con aplicación | PC | `http://dev.abaco.test/app/` | `Aplicación detrás del proxy` | ✅ |
| 8080 no accesible desde fuera | PC | `http://192.168.56.102:8080` | No carga (UFW descarta) | ✅ |

Diagnóstico del 502 (útil para el día 4):
```bash
tail -1 /var/log/nginx/dev.error.log
# connect() failed (111: Connection refused) while connecting to upstream, upstream: "http://127.0.0.1:8080/"
ss -ltn | grep 8080          # vacío: no hay nada escuchando en el 8080
```

#### Recorrido de una petición (completado el 15 oct)
Una petición va del PC a la red solo-anfitrión, la interfaz de la VM, el puerto 80, Nginx y el sitio o la
aplicación. Cada comando comprueba un eslabón:

| Comando (en la VM) | Qué comprueba | Resultado |
|---|---|---|
| `ip -br a` | Que las interfaces tienen IP | `enp0s3` 10.0.2.15 (NAT), `enp0s8` 192.168.56.102 (solo-anfitrión), `lo` 127.0.0.1 |
| `ip route` | Por dónde sale el tráfico | `default via 10.0.2.2` (puerta de enlace = NAT de VirtualBox); `192.168.56.0/24` directo por `enp0s8` |
| `ping -c 3 8.8.8.8` | Salida a Internet | 0 % de pérdida |
| `ping -c 3 192.168.56.20` | Que llego al PC | 100 % de pérdida: el firewall de Windows bloquea el ping. La red funciona (SSH entra por ella) |
| `cat /etc/resolv.conf`, `resolvectl status enp0s3` | Qué DNS se usa (16 oct) | `nameserver 127.0.0.53` (systemd-resolved, resolutor local); DNS reales que da el NAT de VirtualBox: `100.100.1.1`, `100.90.1.1`, `192.168.56.10` |
| `resolvectl query ubuntu.com` | Que los nombres se traducen a IP | 7 IPv4 + 7 IPv6 en 52,7 ms, por `enp0s3` |
| `getent hosts dev.abaco.test` | Si la VM conoce nuestros nombres | Nada: `*.abaco.test` solo existe en el `hosts` del PC; en la VM se usa `curl -H "Host: …"` |
| `ss -lntp` | Qué puertos escuchan y dónde | 22 y 80 en `0.0.0.0` / `[::]` (todas las interfaces) |
| `curl -I -H "Host: dev.abaco.test" http://localhost` | Que Nginx responde con el sitio correcto | `200 OK`, `Content-Length: 62` (página DEV) |

Un `200` no basta: hay que mirar **qué** respondió. En un primer intento faltó el `-H`, así que curl tomó
`"host: …"` como URL (`Malformed input`) y pidió `localhost` sin cabecera `Host`. Contestó el sitio por defecto,
también con `200`, pero con `Content-Length: 615` (la página "Welcome to nginx").

#### Log de accesos y códigos de error
```bash
curl -i -H "Host: dev.abaco.test" http://localhost/noexiste      # HTTP/1.1 404 Not Found
sudo tail -5 /var/log/nginx/dev.access.log
# 192.168.56.20 - - [14/Oct/2026:15:35:12 +0200] "GET /app/ HTTP/1.1" 304 0 "-" "Mozilla/5.0 (Windows NT 10.0; …) Chrome/…"
# ::1 - - [15/Oct/2026:12:47:08 +0200] "HEAD / HTTP/1.1" 200 0 "-" "curl/8.5.0"
# ::1 - - [15/Oct/2026:12:47:13 +0200] "GET /noexiste HTTP/1.1" 404 162 "-" "curl/8.5.0"
```
Cada línea registra quién (IP), cuándo, qué pidió (método y ruta), el código, los bytes y el programa cliente.
`::1` es la propia VM por IPv6. `304` significa que el navegador ya tenía la página en caché.

| Síntoma | Quién responde | Significado | Dónde mirar |
|---|---|---|---|
| `404 Not Found` | Nginx | Nginx funciona y conoce el sitio, pero la ruta no existe | `*.access.log` (código 404), contenido de `/var/www/…` |
| `502 Bad Gateway` | Nginx | Nginx funciona, pero la aplicación de detrás no responde | `*.error.log` (`connect() failed (111…)`), `ss -ltn` |
| No conecta / se queda cargando | Nadie | No se llega a Nginx: servicio parado, cortafuegos o red | `systemctl status nginx`, `ss -lntp`, `ufw status`, `ip -br a` |

### 9. Problemas encontrados
| # | Problema | Causa | Solución |
|---|---|---|---|
| 1 | Los dos `curl -H "Host: …" http://localhost` devolvían la página por defecto de Nginx | `localhost` también es `::1` (IPv6) y curl lo prueba primero. Nuestros sitios solo tenían `listen 80;` (IPv4); en IPv6 solo escuchaba `default` (`listen [::]:80 default_server`) | Añadir `listen [::]:80;` a los dos sitios. Diagnóstico: misma petición con `curl -4` (bien) y `curl -6` (mal) |
| 2 | Tras el `sed`, PRUEBAS seguía mal y DEV ya funcionaba | El comando, muy largo, se copió cortado y solo incluyó el archivo de DEV. Un `sed` que no encuentra nada no da error | Repetir el `sed` solo para PRUEBAS y comprobar con `head` justo después |
| 3 | `El operador '<' está reservado para uso futuro` | Comando de bash (heredoc `<<'EOF'`) pegado en PowerShell en vez de en la sesión SSH | Pegarlo en la sesión SSH; mirar siempre el prompt. No llegó a ejecutarse nada |
| 4 | "Aplicación" se veía con caracteres raros | El servidor de Python no indica la codificación y el navegador supuso la de Windows | `<meta charset="utf-8">` en el HTML |

### 10. Evidencias (`evidencias/dia2/`)
| Archivo | Contenido |
|---|---|
| `salidas-dia2.txt` | Prueba de acceso con contraseña rechazado, Nginx desde el PC, los dos sitios tras la corrección y el 502 con su log |
| `01-nginx-status.png` | `systemctl status nginx`: active (running), enabled |
| `02-nginx-curl-localhost.png` | `curl -i http://localhost` → 200 y página por defecto |
| `03-ufw-puerto-80.png` | UFW con 22 y 80 solo desde 192.168.56.20 |
| `04-contenido-sitios.png` | `ls -lR /var/www`: permisos del contenido |
| `05-sites-enabled.png` | Enlaces simbólicos en `sites-enabled` |
| `06-nginx-t.png` | `nginx -t`: syntax is ok |
| `07-` y `08-problema-…-pagina-por-defecto.png` | Problema 1: los dos sitios devolvían la página por defecto |
| `09-solucion-curl-dev.png` | DEV correcto tras añadir `listen [::]:80;` |
| `10-navegador-dev.png` / `11-navegador-pruebas.png` | Los dos sitios desde el navegador del PC |
| `12-proxy-502-sin-aplicacion.png` | `nginx -t` + 502 sin aplicación detrás |
| `13-navegador-proxy-app.png` | `dev.abaco.test/app/` servido por la aplicación |
| `14-puerto-8080-bloqueado-y-log-python.png` | 8080 sin respuesta desde el PC y log de la aplicación (`127.0.0.1`, `GET /`, `304`) |
| `15-recorrido-ip-ping-route.png` | `ip -br a`, `ping` al PC (bloqueado) y a 8.8.8.8, `ip route` (15 oct) |
| `16-recorrido-ss-curl.png` | `ss -lntp` y el `curl` sin `-H` (página por defecto, 615 bytes) |
| `17-curl-dev-404-access-log.png` | `curl` correcto a DEV (62 bytes), 404 y `dev.access.log` |
| `../dia4/02-dns-resolv-resolvectl-getent.png` | DNS: `resolv.conf`, `resolvectl status/query`, `getent` sin resultado (16 oct) |

### 11. Punto de restauración
Snapshot de VirtualBox `dia2-nginx-ok` antes de empezar con Docker:
```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" snapshot abaco-lab take "dia2-nginx-ok" --description "..."
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" snapshot abaco-lab list
```
Resultado: `Name: dia2-nginx-ok (UUID: 803db18e-…) *` con la descripción "14 oct: SSH sin contraseña ni root,
Nginx con dev y pruebas, proxy /app/. Antes de Docker." (el `*` marca el estado actual).

Un snapshot no es una copia de seguridad (vive en el mismo disco que la VM); las copias se hacen el día 4.

### 12. Qué he aprendido, dificultades y pendientes

#### Qué he aprendido

**Archivo correcto ≠ servicio aplicándolo**
`sshd -t` y `-T` leen el archivo del disco, pero el servicio en marcha mantiene la configuración antigua. `reload`
hace que el servicio relea la configuración sin pararse; `restart` lo para y lo vuelve a arrancar (si la
configuración tiene un error, no vuelve a arrancar).

**La umask depende del usuario**
La umask depende del usuario: en este caso, con `sudo` la umask es 0022 y con mi usuario es 0002.

**`sites-available` / `sites-enabled` y `.test`**
Cada sitio tiene su archivo en `available`, y se activa con un enlace en `enabled`. Para apagarlo se borra el
enlace, sin perder la configuración, y no se toca `nginx.conf`. `.test` es un dominio reservado para pruebas que
nunca existirá en Internet.

**IPv4 frente a IPv6**
`localhost` es `127.0.0.1` y también `::1`, y curl prueba primero IPv6. Un sitio con solo `listen 80;` no atiende
IPv6, así que hace falta también `listen [::]:80;`. El método de diagnóstico: repetir la misma petición cambiando
una sola cosa (`curl -4` frente a `curl -6`).

**Proxy inverso y 502**
Nginx recibe la visita y la pasa a una aplicación interna. Si la aplicación no está, da `502 Bad Gateway`. El
diagnóstico tiene dos partes: el log del sitio (`connection refused`) y `ss -ltn`, que muestra si alguien escucha
en ese puerto.

**Codificación UTF-8**
Si el servidor no dice en qué codificación va la página, el navegador adivina y las tildes salen rotas. Se arregla
declarando `<meta charset="utf-8">` en el HTML.

**Defensa en profundidad (8080)**
La aplicación es inaccesible desde fuera por dos barreras independientes: UFW descarta el tráfico y la aplicación
solo escucha en `127.0.0.1`. Que el navegador se quede cargando es buena señal: UFW descarta en silencio y no da
pistas.

**Snapshot ≠ copia de seguridad**
Un snapshot es una foto de la VM para volver atrás antes de un cambio grande. Vive en el mismo disco que la VM: si
este se pierde, se pierden los dos. Las copias de verdad se guardan en otro sitio.

#### Dificultades
| Problema | Causa | Cómo lo resolví |
|---|---|---|
| Los sitios devolvían la página por defecto de Nginx | Nuestros sitios solo escuchaban en IPv4; `localhost` fue por IPv6 y ahí solo respondía `default` | Añadir `listen [::]:80;` a los dos sitios |
| "Aplicación" se veía con caracteres raros | Faltaba declarar la codificación de la página | `<meta charset="utf-8">`; el primer intento no se guardó y lo detectamos mirando el archivo |

#### Pendientes
- Jueves 15: Docker Compose (`abaco-dev` en 3001 y `abaco-pruebas` en 3002) detrás de Nginx; el proxy `/app/`
  pasará de la aplicación de Python a un contenedor.
- Viernes 16: copias, restauración, provocar fallos (Nginx parado y 502) y RCA.

---

## Parte 2 · Docker Compose (jueves 15)

### 1. Objetivo
- Empaquetar la web en una imagen Docker y arrancarla como **dos proyectos Compose independientes**:
  `abaco-dev` y `abaco-pruebas`, cada uno con su puerto, su imagen y su volumen.
- Poner Nginx de la VM delante: cada nombre lleva a su contenedor.
- Demostrar que cambiar DEV no toca PRUEBAS y que recrear un contenedor conserva su dato.

### 2. Esquema
```
                                 ┌──────────────────────── VM abacolab 192.168.56.102 ─────────────────────────┐
[ PC 192.168.56.20 ]             │                                                                             │
  navegador ── HTTP :80 ── UFW ──┼─▶ Nginx ── Host: dev.abaco.test     ──▶ 127.0.0.1:3001 ─▶ abaco-dev-web-1      │
  (hosts: *.abaco.test           │          ── Host: pruebas.abaco.test ──▶ 127.0.0.1:3002 ─▶ abaco-pruebas-web-1  │
   → 192.168.56.102)             │                                                (:8080 dentro, volumen /datos) │
                                 │   3001 y 3002 solo en 127.0.0.1: no accesibles desde fuera                  │
                                 └─────────────────────────────────────────────────────────────────────────────┘
```

### 3. Instalación de Docker (repositorio oficial)
Se usa el repositorio de Docker y no el paquete `docker.io` de Ubuntu (más antiguo y sin el plugin `compose`).
```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update                      # aparece download.docker.com … noble InRelease
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run hello-world
```
| Componente | Versión |
|---|---|
| Docker Engine | 29.9.1 (build dfc520d) |
| Docker Compose (plugin) | v5.6.0 |
| containerd | 2.4.2 |

`docker` y `containerd` quedan `active` y `enabled` (arrancan al encender la VM).

**Decisión de seguridad:** se usa `sudo docker` y **no** se añade samiabaco al grupo `docker`. El demonio corre
como root y quien puede usar `/var/run/docker.sock` (`root:docker`, `srw-rw----`) controla la máquina entera
(p. ej. `docker run -v /:/host …`). Con `sudo` se pide contraseña y queda registro en `/var/log/auth.log`.
Comprobación: `docker ps` sin sudo → `permission denied … docker.sock`.

### 4. Archivos (`docker/dev/` y `docker/pruebas/`)
Los archivos se escriben en el repositorio del PC, se suben a GitHub y la VM los obtiene con
`git clone` / `git pull` (la VM solo lee el repositorio, nunca hace push).

`Dockerfile` (idéntico en los dos entornos):
```dockerfile
FROM python:3.12-alpine
WORKDIR /web
COPY index.html .
EXPOSE 8080
CMD ["python", "-m", "http.server", "8080", "--bind", "0.0.0.0"]
```
`compose.yaml` (idéntico salvo el comentario):
```yaml
services:
  web:
    build: .
    image: abaco-web:${TAG:?falta TAG en .env}
    ports:
      - "127.0.0.1:${PUERTO:?falta PUERTO en .env}:8080"
    volumes:
      - datos:/datos
    restart: unless-stopped

volumes:
  datos:
```
`.env.example` (versionado) → se copia a `.env` (ignorado por `.gitignore`, local de cada servidor):

| Entorno | `TAG` | `PUERTO` |
|---|---|---|
| DEV | `dev-1` → `dev-2` | `3001` |
| PRUEBAS | `pruebas-1` | `3002` |

- `--bind 0.0.0.0` dentro del contenedor: el contenedor tiene su propia red; si escuchara en su `127.0.0.1`,
  Docker no podría pasarle las visitas.
- `127.0.0.1:` en `ports`: el puerto solo se publica en el localhost de la VM. **Docker escribe sus reglas de
  iptables por delante de UFW**: con `"3001:8080"` (sin IP) el puerto quedaría abierto a la red aunque UFW lo
  deniegue.
- `.env` solo rellena variables de Compose; no cambia el contenido de la web.

### 5. Puesta en marcha (en la VM)
```bash
git clone https://github.com/LSY13/abaco-lab ~/abaco-lab

cd ~/abaco-lab/docker/dev
cp .env.example .env
sudo docker compose -p abaco-dev config            # compose resuelto: abaco-web:dev-1, 127.0.0.1:3001
sudo docker compose -p abaco-dev up -d --build
sudo docker compose -p abaco-dev ps
curl http://127.0.0.1:3001

cd ~/abaco-lab/docker/pruebas
cp .env.example .env
sudo docker compose -p abaco-pruebas up -d --build
sudo docker compose -p abaco-pruebas ps
curl http://127.0.0.1:3002
```
**Siempre con `-p`**: sin él, Compose usa el nombre de la carpeta (`dev`, `pruebas`) y crearía otros
recursos (`dev_datos`…), con un volumen nuevo y vacío.

| Proyecto | Contenedor | Imagen | Puerto (VM → contenedor) | Volumen | Red |
|---|---|---|---|---|---|
| `abaco-dev` | `abaco-dev-web-1` | `abaco-web:dev-2` (antes `dev-1`) | `127.0.0.1:3001 → 8080` | `abaco-dev_datos` → `/datos` | `abaco-dev_default` |
| `abaco-pruebas` | `abaco-pruebas-web-1` | `abaco-web:pruebas-1` | `127.0.0.1:3002 → 8080` | `abaco-pruebas_datos` → `/datos` | `abaco-pruebas_default` |

Caché de capas: el build de PRUEBAS reutilizó la base de Python y `WORKDIR` (`CACHED`) y tardó 2,2 s frente a
7,7 s; solo se rehízo `COPY` (el `index.html` es distinto). Las imágenes marcan 83 MB cada una pero comparten
las capas de Python.

### 6. Nginx delante de los contenedores
`nginx/dev.abaco.test` (PRUEBAS igual con `pruebas.abaco.test` y `:3002`). Se quitan `root`, `try_files` y
`location /app/`: todo el sitio lo sirve el contenedor.
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name dev.abaco.test;

    access_log /var/log/nginx/dev.access.log;
    error_log  /var/log/nginx/dev.error.log;

    location / {
        proxy_pass http://127.0.0.1:3001/;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```
```bash
sudo cp ~/abaco-lab/nginx/dev.abaco.test ~/abaco-lab/nginx/pruebas.abaco.test /etc/nginx/sites-available/
sudo nginx -t && sudo systemctl reload nginx
rm -r ~/app-prueba                                 # la app de Python del día 2 ya no se usa
```
Nginx sigue siendo la única puerta (80 en UFW): distingue los sitios por nombre, centraliza los logs y podría
añadir HTTPS. `/var/www/dev` y `/var/www/pruebas` quedan en la VM sin uso.

### 7. Cambiar solo DEV y recrear PRUEBAS
Dato de prueba en cada volumen:
```bash
sudo docker compose -p abaco-dev exec web sh       # prompt /web # (dentro del contenedor)
echo "dato DEV" > /datos/prueba.txt                 # en PRUEBAS: "dato PRUEBAS"
exit
```
Cambio solo en DEV (nueva línea "Versión 2" en el HTML y nueva etiqueta):
```bash
cd ~/abaco-lab && git pull                          # actualiza .env.example, NO el .env local
cd docker/dev
sed -i 's/^TAG=dev-1/TAG=dev-2/' .env && cat .env
sudo docker compose -p abaco-dev up -d --build
sudo docker compose -p abaco-dev exec web cat /datos/prueba.txt     # dato DEV
```
Con etiqueta nueva conviven `dev-1` y `dev-2`: volver atrás es `TAG=dev-1` y `up -d`.

Recrear PRUEBAS sin cambiar nada:
```bash
cd ~/abaco-lab/docker/pruebas
sudo docker compose -p abaco-pruebas up -d --force-recreate        # sin -v
sudo docker compose -p abaco-pruebas exec web cat /datos/prueba.txt # dato PRUEBAS
```
**`down -v` borra los volúmenes (los datos).** `down` sin `-v` los conserva.

### 8. Pruebas
| Prueba | Desde | Comando / URL | Resultado esperado | Resultado |
|---|---|---|---|---|
| Docker sin sudo | VM | `docker ps` | `permission denied … docker.sock` | ✅ (esperado) |
| Docker funciona | VM | `sudo docker run hello-world` | `Hello from Docker!` | ✅ |
| Compose válido (DEV) | VM | `sudo docker compose -p abaco-dev config` | `abaco-web:dev-1`, `127.0.0.1:3001` | ✅ |
| Compose válido (PRUEBAS) | VM | `sudo docker compose -p abaco-pruebas config` | `abaco-web:pruebas-1`, `127.0.0.1:3002`, `abaco-pruebas_datos` | ✅ (16 oct, `evidencias/dia4/01`) |
| Servicios en marcha | VM | `sudo docker compose -p … ps` | `Up` en los dos | ✅ |
| Contenedores directos | VM | `curl http://127.0.0.1:3001` / `:3002` | HTML de cada entorno | ✅ |
| Volúmenes separados | VM | `sudo docker volume ls` | `abaco-dev_datos`, `abaco-pruebas_datos` | ✅ |
| Nginx → contenedores | VM | `curl -H "Host: dev.abaco.test" http://localhost` | "servido desde un contenedor Docker" | ✅ |
| Navegador | PC | `http://dev.abaco.test`, `http://pruebas.abaco.test` | Cada uno su entorno | ✅ |
| Puertos no accesibles desde fuera | PC | `curl.exe -m 5 http://192.168.56.102:3001` / `:3002` | Sin conexión | ✅ (`Connection timed out`) |
| Escuchan solo en localhost | VM | `ss -lnt \| grep 300` | `127.0.0.1:3001` y `127.0.0.1:3002` | ✅ |
| Cambiar DEV no toca PRUEBAS | VM / PC | `curl` a los dos + `docker ps` | DEV con "Versión 2"; PRUEBAS sin ella y sin recrear | ✅ |
| DEV recreado conserva el dato | VM | `exec web cat /datos/prueba.txt` | `dato DEV` | ✅ |
| PRUEBAS recreado conserva el dato | VM | `up -d --force-recreate` + `exec … cat` | `dato PRUEBAS` | ✅ |

### 9. Evidencias (`evidencias/dia3/`)
| Archivo | Contenido |
|---|---|
| `01-clave-y-fuente-docker.png` | Clave GPG y `docker.sources` con `Suites: noble` |
| `02-apt-update-repo-docker.png` | `apt update` con `download.docker.com` |
| `03-apt-install-docker.png` | Instalación de los paquetes de Docker |
| `04-docker-ps-denegado-y-hello-world.png` | `docker ps` sin sudo (denegado) y `hello-world` |
| `05-docker-images-y-ps-a.png` | Imagen `hello-world` y contenedor `Exited (0)` |
| `06-clone-y-env.png` | `git clone` en la VM y `.env` de DEV |
| `07-compose-config-dev.png` | `compose config` resuelto |
| `08-up-build-dev.png` | Build y arranque de DEV |
| `09-ps-y-curl-dev.png` | DEV `Up` y `curl 127.0.0.1:3001` |
| `10-` y `11-…-pruebas.png` | `git pull`, build (con caché), `ps` y `curl` de PRUEBAS |
| `12-volumenes-e-imagenes.png` | Dos volúmenes y dos imágenes |
| `13-nginx-proxy-contenedores.png` | `nginx -t`, reload y los dos sitios por Nginx |
| `14-retirada-app-prueba.png` | `~/app-prueba` borrada |
| `15-` y `16-navegador-…-contenedor.png` | Los dos sitios desde el navegador del PC |
| `17-puertos-3001-3002-no-accesibles-desde-pc.png` | `Connection timed out` desde el PC |
| `18-dato-en-volumenes-dev-y-pruebas.png` | `exec web sh` y el dato en cada volumen |
| `19a-` y `19b-…env….png` | `git pull` (`.env` sigue en `dev-1`) y `sed` a `dev-2` |
| `20-build-dev-2-images-ps.png` | Build `dev-2`, imágenes `dev-1` y `dev-2`, PRUEBAS sin recrear |
| `21-curl-dev-v2-pruebas-v1.png` | DEV con "Versión 2", PRUEBAS sin ella |
| `21b-dato-dev-conservado-tras-recrear.png` | `dato DEV` en el contenedor nuevo |
| `22-navegador-dev-version-2.png` | "Versión 2" con la tilde correcta |
| `23-recrear-pruebas-conserva-dato.png` | `--force-recreate` de PRUEBAS y `dato PRUEBAS` |

### 10. Para el viernes (copias)
- Dato a copiar y restaurar: volumen **`abaco-dev_datos`**, archivo **`/datos/prueba.txt`** (`dato DEV`).
  En la VM vive en `/var/lib/docker/volumes/abaco-dev_datos/_data/` (solo root).
- Configuración a copiar: `docker/`, `nginx/` (ya en Git) y los `.env` locales (fuera de Git).

### 11. Punto de restauración
Snapshot de VirtualBox `dia3-docker-ok` antes de empezar con las copias:
```powershell
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" snapshot abaco-lab take "dia3-docker-ok" --description "..."
& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" snapshot abaco-lab list
```
Resultado: `dia3-docker-ok (UUID: 4596afba-…) *` colgando de `dia2-nginx-ok`, con la descripción "15 oct: Docker
oficial (sudo docker), abaco-dev 3001 y abaco-pruebas 3002 en 127.0.0.1, Nginx delante, dato en volumenes.
Antes de copias." (el `*` marca el estado actual).

### 12. Qué he aprendido
Apartado de aprendizajes del día 3.
