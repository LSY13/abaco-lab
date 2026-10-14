# Despliegue · Nginx (día 2) y Docker Compose (día 3)

## Parte 1 · Nginx: dos sitios y proxy inverso (miércoles 14)

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
_pendiente_
