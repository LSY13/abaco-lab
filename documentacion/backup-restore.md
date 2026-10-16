# Copia de seguridad y restauración (día 4 · viernes 16)

## 1. Objetivo
Copiar la configuración (Nginx y Compose) y el dato persistente de DEV, guardar la copia fuera de la VM,
restaurarla en una ubicación nueva **sin tocar los originales** y validar su contenido y su funcionamiento.
"Una copia solo queda demostrada cuando has restaurado y validado su contenido."

## 2. Qué se copia
| Copia | Contenido | Por qué |
|---|---|---|
| `config-2026-10-16.tar.gz` (2910 B) | `/etc/nginx/sites-available/` (`default`, `dev.abaco.test`, `pruebas.abaco.test`) y `~/abaco-lab/docker/` (`dev/` y `pruebas/`: `Dockerfile`, `compose.yaml`, `index.html`, `.env.example` y **`.env`**) | Configuración para reconstruir los servicios. Los `.env` solo existen en la VM (no están en Git) |
| `volumen-abaco-dev_datos-2026-10-16.tar.gz` (143 B) | Volumen `abaco-dev_datos`: `./prueba.txt` (9 B, `dato DEV`) | El dato persistente identificado el jueves |
| `SHA256SUMS` | Hash SHA-256 de las dos copias | Comprobar que no cambian al moverlas |

## 3. Dónde se guarda
| Ubicación | Ruta | Papel |
|---|---|---|
| VM | `~/backups/` | Donde se crean |
| **PC (copia fuera del servidor)** | `C:\Users\ghall\abaco-entrega\backups\` | Fuera de la VM y del repositorio (`.gitignore` ignora `backups/` y `*.tar.gz`) |
| VM (prueba de restauración) | `~/restore-test/` y volumen `abaco-dev_restore` | Ubicación nueva para restaurar sin tocar los originales |

Un snapshot de VirtualBox no sustituye a esta copia: vive en el mismo disco que la VM.

## 4. Crear la copia (VM)
```bash
mkdir -p ~/backups
cd ~

# Configuración: rutas relativas (-C /) para que al restaurar no se escriba encima de /etc por accidente
sudo tar -czf ~/backups/config-2026-10-16.tar.gz -C / etc/nginx/sites-available home/samiabaco/abaco-lab/docker
tar -tzvf ~/backups/config-2026-10-16.tar.gz          # listar sin extraer

# Volumen, sin escrituras: se para DEV durante la copia (ventana de corte de unos segundos)
cd ~/abaco-lab/docker/dev
sudo docker compose -p abaco-dev stop
sudo docker run --rm -v abaco-dev_datos:/datos:ro -v ~/backups:/backup alpine:3.20 tar -czf /backup/volumen-abaco-dev_datos-2026-10-16.tar.gz -C /datos .
sudo docker compose -p abaco-dev start
tar -tzvf ~/backups/volumen-abaco-dev_datos-2026-10-16.tar.gz

# Huellas
cd ~/backups
sha256sum *.tar.gz | tee SHA256SUMS
```
El volumen se copia con un contenedor temporal (`--rm`) que lo monta en solo lectura (`:ro`), método de la
documentación de Docker. `stop`/`start` no recrea el contenedor (seguía "creado hace 23 horas").

## 5. Llevar la copia al PC (PowerShell)
```powershell
New-Item -ItemType Directory -Force C:\Users\ghall\abaco-entrega\backups
scp "samiabaco@192.168.56.102:backups/*" C:\Users\ghall\abaco-entrega\backups\
Get-FileHash C:\Users\ghall\abaco-entrega\backups\*.tar.gz -Algorithm SHA256 | Format-List Hash, Path
Get-Content C:\Users\ghall\abaco-entrega\backups\SHA256SUMS
```
| Archivo | SHA-256 en la VM | SHA-256 en el PC | |
|---|---|---|---|
| `config-2026-10-16.tar.gz` | `8dea97c9…213c405c` | `8DEA97C9…213C405C` | ✅ Igual |
| `volumen-abaco-dev_datos-2026-10-16.tar.gz` | `0b556ebf…cec7fe0c` | `0B556EBF…CEC7FE0C` | ✅ Igual |

## 6. Restaurar (en una ubicación nueva, desde la copia del PC)
Se restaura desde la copia del PC para simular el caso real: el servidor ha perdido los datos y solo queda la
copia de fuera.
```bash
mkdir -p ~/restore-test/config                                                     # VM
scp C:\Users\ghall\abaco-entrega\backups\* samiabaco@192.168.56.102:restore-test/   # PC
cd ~/restore-test && sha256sum -c SHA256SUMS                                        # VM: OK, OK
```
Configuración:
```bash
tar -xzf ~/restore-test/config-2026-10-16.tar.gz -C ~/restore-test/config
diff -r ~/restore-test/config/etc/nginx/sites-available /etc/nginx/sites-available && echo "NGINX IDENTICO"
diff -r ~/restore-test/config/home/samiabaco/abaco-lab/docker ~/abaco-lab/docker && echo "DOCKER IDENTICO"
```
Volumen, en uno nuevo (`abaco-dev_restore`), y prueba de funcionamiento con un contenedor temporal de la imagen
de DEV en un puerto de pruebas (`127.0.0.1:3091`):
```bash
sudo docker volume create abaco-dev_restore
sudo docker run --rm -v abaco-dev_restore:/datos -v ~/restore-test:/backup:ro alpine:3.20 tar -xzf /backup/volumen-abaco-dev_datos-2026-10-16.tar.gz -C /datos
sudo docker run -d --name restore-prueba -p 127.0.0.1:3091:8080 -v abaco-dev_restore:/datos abaco-web:dev-2
curl http://127.0.0.1:3091
sudo docker exec restore-prueba cat /datos/prueba.txt                 # restaurado
sudo docker compose -p abaco-dev exec web cat /datos/prueba.txt       # original
sudo docker rm -f restore-prueba
```

## 7. Prueba antes / después
| Comprobación | Original | Restaurado | Resultado |
|---|---|---|---|
| Integridad tras ir y volver del PC | Hashes de `SHA256SUMS` | `sha256sum -c` en `~/restore-test` | ✅ `OK` en los dos |
| Configuración de Nginx | `/etc/nginx/sites-available/` | `~/restore-test/config/etc/nginx/sites-available/` | ✅ `diff -r` sin diferencias (`NGINX IDENTICO`) |
| Configuración de Compose (con `.env`) | `~/abaco-lab/docker/` | `~/restore-test/config/home/samiabaco/abaco-lab/docker/` | ✅ `diff -r` sin diferencias (`DOCKER IDENTICO`) |
| Dato persistente | `abaco-dev_datos:/datos/prueba.txt` → `dato DEV` | `abaco-dev_restore:/datos/prueba.txt` → `dato DEV` | ✅ Igual |
| Funcionamiento | `dev.abaco.test` (DEV, versión 2) | Contenedor `restore-prueba` con el volumen restaurado en `127.0.0.1:3091` | ✅ Sirve la web de DEV (versión 2) y lee el dato restaurado |
| Originales intactos | DEV y PRUEBAS en 3001/3002 | — | ✅ Siguen en marcha y responden `200` por Nginx |

Queda en la VM, como evidencia, el volumen `abaco-dev_restore` (se puede borrar con
`sudo docker volume rm abaco-dev_restore`).

## 8. Cómo restaurar de verdad (si se perdieran los originales)
No se ha ejecutado (el PDF pide restaurar en otra ubicación, sin borrar datos). Pasos:
1. Configuración: `sudo tar -xzf config-….tar.gz -C /` → `sudo nginx -t && sudo systemctl reload nginx`.
2. Dato: con DEV parado (`compose -p abaco-dev stop`), extraer la copia en `abaco-dev_datos` con el mismo
   `docker run … tar -xzf` del §6 y arrancar (`compose -p abaco-dev start`).
3. Comprobar con las pruebas del §7.

## 9. Evidencias (`evidencias/dia4/`)
| Archivo | Contenido |
|---|---|
| `09a-error-tar-linea-partida.png` | Primer intento: la línea del `tar` se pegó partida y la copia salió incompleta (2 archivos, 532 B); se detectó con `tar -tzvf` y se repitió |
| `09-tar-config-listado.png` | `tar -tzvf` de la configuración (Nginx y `docker/` con los `.env`) |
| `10-stop-copia-volumen-start.png` | `stop`, copia del volumen con Alpine, `start` y `ps` |
| `11-tar-volumen-listado.png` | Contenido de la copia del volumen (`./prueba.txt`, 9 B) |
| `12-sha256-y-ls-backups.png` | Hashes y `ls -l ~/backups` |
| `13-scp-al-pc-y-hashes.png` | `scp` al PC y comparación de hashes |
| `14a-scp-pc-a-vm.png` / `14b-sha256-check-vm.png` | Copia del PC devuelta a la VM y `sha256sum -c` |
| `15-restaurar-config-diff.png` | Extracción de la configuración y los dos `diff` |
| `16-restaurar-volumen-y-probar.png` | Volumen nuevo, extracción, contenedor de prueba, `curl` y los dos `cat` |
| `17-borrar-contenedor-prueba.png` | `docker rm -f restore-prueba` |
