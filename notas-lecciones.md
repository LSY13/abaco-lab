# Lecciones pendientes de apuntar con mis palabras

Lista de temas vistos. Al final del día escribo cada uno en `documentacion/instalacion.md`
(sección "Qué he aprendido") explicándolo yo.

## Día 1 · Martes 13
1. **Repositorio y .gitignore**: por qué la configuración se versiona y por qué los secretos nunca entran en Git.
2. **Markdown en vez de Word**: texto plano, Git ve los cambios línea a línea.
3. **Equipo físico, VM y VPS**: qué es un hipervisor y por qué no se le dan todos los recursos a la VM.
4. **Dos tarjetas de red**: NAT (salir a Internet) y solo-anfitrión (PC ↔ VM).
5. **10.0.2.x frente a 192.168.56.x** _(corregida el 14 oct)_: son dos redes distintas, ambas de IPs privadas.
   Dos equipos se hablan **directamente** solo si están en la misma subred (PC 192.168.56.20 ↔ VM 192.168.56.102).
   Entre redes distintas también hay comunicación, pero **a través de un router o puerta de enlace**: la VM sale a
   Internet desde 10.0.2.15 porque el NAT de VirtualBox hace de router.
6. **VirtualBox frente a otros hipervisores**: los conceptos valen para todos.
7. **Verificar antes de avanzar**: revisar la VM antes de arrancar (encontramos 2 fallos).
8. **Fallos encontrados**: adaptador 2 desactivado y tipo de SO en Windows 11. Por qué importaban.
9. **Interfaz gráfica frente a terminal (VBoxManage)**: los comandos se documentan, repiten y automatizan.
10. **Ubuntu Desktop frente a Server**: un servidor no tiene escritorio y se administra por SSH.
11. **Instalación desatendida**: por qué la omitimos.
12. **Disco dinámico frente a preasignado.**
13. **Drivers de terceros**: no hacen falta en una VM; en un servidor se instala solo lo necesario.
14. **LVM**: volúmenes ampliables en caliente; `ubuntu-lv` venía a la mitad (18,5 GB) y lo ampliamos a ~36,9 GB.
15. **Particiones**: `/boot/efi`, `/boot` y `/`.
16. **Repositorio privado y colaboradores.**
17. **`ip -br a` y otros subcomandos de `ip`**: por qué `ip` y no `ifconfig` ni `ipconfig`.
18. **`apt update` frente a `apt upgrade`**: por qué se actualiza nada más instalar.
19. **Rutas absolutas y relativas, `~`, espacios en los comandos y la tecla Tab.**
20. **Permisos `rwx` y numéricos (644/600/700) frente a umask** _(corregida el 14 oct)_: el **permiso** lo tiene
    cada archivo. La **umask** no es un permiso: es una máscara que **quita** permisos a lo que se crea. En Ubuntu
    vale `0002`, así que los archivos nacen con 666 − 002 = **664** y las carpetas con 777 − 002 = **775**
    (664 es el resultado, no la umask). El caso de `cat` denegado y `sudo cat` permitido.
21. **`sudo` y el principio de mínimo privilegio.**
22. **Leer los errores** (`chmode`, `ping -c 3` sin destino) y pedir ayuda con un error concreto.
23. **El prompt indica en qué máquina estás** (clave creada por error en la VM).
24. **Fingerprint y `known_hosts`.**
25. **Clave pública (candado) y privada (llave)**; `authorized_keys` y sus permisos.
26. **UFW**: denegar lo entrante por defecto, permitir 22 solo desde el PC, permitir antes de activar.
27. **`PermitRootLogin no`**, `sshd_config.d/`, `sudo tee`, `sshd -t` frente a `sshd -T`.
28. **Orden de los archivos en `sshd_config.d`** (gana el primer valor; el caso `50-cloud-init`). Resuelto el miércoles (ver día 2).
29. **No cerrar la única sesión abierta** antes de probar otra.

## Día 2 · Miércoles 14
1. **`sshd_config.d`: gana el primer valor, no el último.** Nuestro `99-abaco.conf` se leía después de
   `50-cloud-init.conf` (`PasswordAuthentication yes`), así que nunca podía anularlo. Solución: renombrarlo a
   `10-abaco.conf` en vez de editar o borrar un archivo que no es nuestro. En otros programas gana el último:
   verificar siempre el valor efectivo (`sshd -T`).
2. **Archivo correcto ≠ servicio aplicándolo**: `sshd -t`/`-T` leen el disco; el servicio en marcha necesita
   `systemctl reload ssh` (relee sin pararse; `restart` para y arranca, y si la configuración falla no vuelve).
3. **Qué es Nginx**: servidor web (puerto 80) que sirve archivos y hace de proxy inverso; varios sitios en una
   misma IP se distinguen por el nombre (cabecera `Host`, *server blocks*).
4. **Leer `systemctl status`**: `enabled` = arranca al encender; `active (running)`; un proceso *master* (lee
   la configuración, corre como root) y *workers* (atienden visitas, sin privilegios), uno por CPU.
5. **`curl -I` frente a `curl -i`**: `-I` pide solo las cabeceras; `-i` las cabeceras y la página. `200 OK` = éxito.
   La fecha HTTP siempre va en GMT (11:34 GMT = 13:34 en Madrid).
6. **La umask depende del usuario**: lo creado con `sudo` sale 644/755 (umask de root `0022`), no 664/775
   (umask de samiabaco `0002`). Nginx (`www-data`) solo necesita la `r` de "otros" para leer la web.
7. **`sites-available` / `sites-enabled`**: configuración de cada sitio aparte, activada con un enlace simbólico
   (`ln -s`); no se toca `nginx.conf`. Dominio `.test` reservado para pruebas (RFC 6761).
8. **Problema: IPv4 frente a IPv6.** `curl -H "Host: dev.abaco.test" http://localhost` devolvía la página por
   defecto. Causa: `localhost` también es `::1` (IPv6) y curl lo prueba primero; nuestros sitios solo tenían
   `listen 80;` (IPv4) y en IPv6 solo escuchaba `default` (`listen [::]:80 default_server`). Con `127.0.0.1` (o
   `curl -4`) salía bien. Solución: añadir `listen [::]:80;`. Aislar la variable: misma petición, cambiar solo una cosa.
9. **Comprobar justo después de cada cambio**: el `sed` largo se copió cortado y solo cambió `dev`. Un `sed`
   que no encuentra nada no da error. El `head` de después lo habría mostrado; mirar la salida antes de seguir.
10. **Archivo `hosts`**: el PC lo consulta antes que el DNS; apuntamos `*.abaco.test` a la VM a mano (como admin,
    el "sudo" de Windows). "No es seguro" en el navegador = HTTP sin cifrar (no hay HTTPS/TLS).
11. **Problema: comando de Linux pegado en PowerShell** (la ventana de administrador del `hosts`). Error
    `El operador '<' está reservado`: PowerShell no entiende el heredoc `<<'EOF'`. Era un error de sintaxis, así
    que no llegó a ejecutarse nada. Otra vez: mirar el prompt (`PS C:\…>` = Windows; `samiabaco@abacolab:~$` = VM).
12. **Proxy inverso y 502 Bad Gateway**: Nginx funciona pero no hay nadie detrás (`connect() failed (111:
    Connection refused)` en `dev.error.log`). Diagnóstico: el log del sitio + `ss -ltn` (¿quién escucha en el puerto?).
    La app escucha en 127.0.0.1, así que no se abre el 8080 en UFW: solo Nginx da la cara.
13. **Codificación (UTF-8)**: "Aplicación" salía mal porque Python no indica la codificación y el navegador
    adivinó la de Windows. Solución: `<meta charset="utf-8">` en el HTML. (DEV/PRUEBAS no tenían tildes.)
14. **Prueba de seguridad del 8080**: desde el PC se queda cargando → UFW descarta en silencio (no da pistas a
    un atacante). Y la app solo escucha en 127.0.0.1: dos barreras independientes (defensa en profundidad).
15. **Procesos en primer plano y log de la app**: el servidor de Python ocupa la terminal (Ctrl+C lo para). Sus
    líneas muestran `127.0.0.1` (le habla Nginx, no el navegador), `GET /` (el proxy quita `/app/`) y `304`
    (el navegador ya tenía la página en caché: "no ha cambiado").
16. **Snapshot de la VM**: foto del estado completo (disco y, con la VM encendida, también la RAM) para volver
    atrás en un clic antes de un cambio grande (Docker mañana). No es una copia de seguridad: vive en el mismo
    disco que la VM y depende de ella; si se pierde el disco, se pierden los dos.
17. **Recorrido de la petición** _(15 oct)_: cada comando comprueba un eslabón (`ip -br a` IP, `ip route` puerta
    de enlace 10.0.2.2, `ping` llegada, `ss -lntp` quién escucha, `curl` qué responde). Un ping fallido no
    significa que no haya red: Windows bloquea el ping y SSH funciona por esa misma red.
18. **Un 200 no basta** _(15 oct)_: sin `-H`, curl tomó `"host: …"` como URL y respondió el sitio por defecto,
    también con 200. La pista era el tamaño (`Content-Length` 615 frente a 62).
19. **`access.log` y 404 / 502 / no conecta** _(15 oct)_: el log dice quién, cuándo, qué, código y tamaño. 404 =
    Nginx funciona pero la ruta no existe; 502 = Nginx funciona pero la app no; no conecta = no se llega a Nginx.

## Día 3 · Jueves 15
1. **Repositorio oficial de Docker frente al paquete de Ubuntu**: `docker.io` de Ubuntu va por detrás y no trae el
   plugin `docker compose` moderno. Se añade el repositorio de Docker a apt con dos piezas:
   - **Clave GPG** (`/etc/apt/keyrings/docker.asc`): la firma de Docker; apt comprueba con ella que los paquetes
     vienen de Docker y no han sido manipulados. `install -m 0755 -d` crea la carpeta con permisos en un paso;
     `chmod a+r` deja que apt lea la clave.
   - **Fuente** (`/etc/apt/sources.list.d/docker.sources`): "busca también aquí y verifica con esta clave"
     (`Signed-By`). `$(. /etc/os-release && echo "$VERSION_CODENAME")` calcula `noble` (Ubuntu 24.04).
   Comprobación: en `apt update` aparece `download.docker.com … noble InRelease`, y en la instalación los
   paquetes vienen de `download.docker.com`. Versiones: Docker 29.9.1, Compose v5.6.0.
2. **`tee` con `sudo`**: `sudo echo … > archivo` falla porque la redirección `>` la hace mi shell (sin permisos);
   `sudo tee` escribe el archivo como root y además lo enseña. En pantalla sale dos veces: lo escrito (con el
   `$(...)` sin resolver) y lo guardado (ya con `noble`).
3. **Actualizaciones "deferred due to phasing"**: Ubuntu reparte algunas actualizaciones poco a poco entre los
   equipos para frenarlas si dan problemas. No hay que hacer nada.
4. **Cliente, demonio y socket**: `docker` es solo el cliente; el trabajo lo hace el demonio `dockerd`, que corre
   como root. Se hablan por `/var/run/docker.sock` (`srw-rw---- root docker`): solo root y el grupo `docker`
   pueden usarlo. Por eso `docker ps` sin sudo da `permission denied … docker.sock`.
5. **Decisión de seguridad: `sudo docker`, no el grupo `docker`**: estar en el grupo `docker` equivale a ser root
   sin contraseña (`docker run -v /:/host …` monta todo el disco dentro de un contenedor y se puede leer o
   cambiar cualquier cosa). Con `sudo` se pide contraseña y queda registrado en `/var/log/auth.log`. Mínimo
   privilegio (día 1).
6. **Los 4 pasos de `hello-world`**: (1) el cliente contacta con el demonio; (2) el demonio no tiene la imagen en
   local (`Unable to find image … locally`) y la descarga de Docker Hub (`Pulling from library/hello-world`,
   `Digest: sha256:…` = huella que identifica la imagen exacta); (3) crea un contenedor a partir de la imagen y
   ejecuta su programa (`/hello`); (4) el demonio pasa la salida al cliente, que la muestra en la terminal.
7. **Imagen frente a contenedor**: la imagen es la plantilla de solo lectura (como un instalador o una clase); el
   contenedor es una copia en marcha de esa imagen (como un programa abierto o un objeto). De una imagen salen
   muchos contenedores. `docker images` lista imágenes (`hello-world:latest`, `latest` = etiqueta/versión;
   `U` en EXTRA = en uso por algún contenedor; *content size* = descarga comprimida, *disk usage* = lo que ocupa
   descomprimida). `docker ps` muestra contenedores en marcha y `ps -a` también los parados: `Exited (0)` = hizo
   su tarea y terminó sin error (0 = éxito, como cualquier comando de Linux). El nombre (`distracted_edison`) lo
   inventa Docker si no le damos uno.
8. **Dockerfile frente a compose.yaml**: el Dockerfile dice **qué hay dentro** de la imagen (base, archivos,
   programa); compose.yaml dice **cómo se ejecuta** en esta máquina (puerto, volumen, reinicio). La misma imagen
   se puede arrancar con otro compose y otro puerto.
9. **`.env` y `.env.example`**: Compose rellena los `${TAG}` y `${PUERTO}` con el `.env` de la carpeta. `.env`
   (el real, podría tener secretos) está en `.gitignore` y no se sube; `.env.example` es la plantilla que sí se
   sube. Tras el `git clone`, `.env` no existe hasta hacer `cp`. `${TAG:?mensaje}` hace que falle con un error
   claro si falta. `.env` solo cambia variables de Compose, no el HTML.
10. **`docker compose config`**: enseña el compose ya resuelto (sin `${…}`) sin arrancar nada. Comprobar antes
    de arrancar.
11. **Nombre de proyecto (`-p`)**: Compose pone delante de todo el nombre del proyecto (`abaco-dev_datos`,
    `abaco-dev_default`, `abaco-dev-web-1`). Sin `-p` usaría el nombre de la carpeta (`dev`) y crearía otro
    volumen distinto, vacío. Ponerlo siempre.
12. **Capas del build**: cada instrucción del Dockerfile es una capa (`[1/3] FROM`, `[2/3] WORKDIR`, `[3/3] COPY`).
    `FROM` descargó la base de Python en varias capas (`sha256:…`). Si se repite el build sin cambios, Docker
    reutiliza las capas de la caché. `up -d --build`: construye y arranca en segundo plano (`-d` = detached).
    Compose crea 4 cosas: imagen, red, volumen y contenedor.
13. **`0.0.0.0` dentro del contenedor, `127.0.0.1` en la VM**: el contenedor tiene su propia red; si Python
    escuchara en el `127.0.0.1` del contenedor, Docker no podría pasarle visitas. En la VM se publica
    `127.0.0.1:3001->8080` para que solo Nginx (en la misma VM) llegue.
14. **Un contenedor no es una VM**: es un proceso normal del mismo kernel, aislado (red, archivos y procesos
    propios). `pgrep -af http.server` en la VM lo muestra como un proceso más. Por eso arranca en un segundo.
15. **Por qué Nginx sigue delante de los contenedores**: es la única puerta abierta (80 en UFW); distingue
    DEV/PRUEBAS por el nombre, centraliza los logs y mañana podría añadir HTTPS. Los contenedores quedan
    escondidos en `127.0.0.1`. Mismo patrón que `/app/` del día 2, pero ahora el contenedor sirve el sitio entero
    (se quitan `root`, `try_files` y `/app/`).
16. **Regla de la caché de capas**: en el build de PRUEBAS, `WORKDIR` salió `CACHED` y la base de Python no se
    volvió a descargar (2,2 s frente a 7,7 s), pero `COPY` se rehízo porque el `index.html` es distinto. En cuanto
    una capa cambia, se rehacen esa y todas las siguientes: lo que cambia a menudo va al final del Dockerfile.
    Las imágenes `dev-1` y `pruebas-1` marcan 83 MB cada una, pero comparten las capas de Python.
17. **Docker se salta UFW**: Docker escribe sus reglas de iptables por delante de UFW. Con `ports: "3001:8080"`
    (sin IP) el puerto quedaría abierto a toda la red aunque UFW diga que no. Por eso la protección va en el
    compose (`127.0.0.1:…`). Prueba desde el PC: `curl.exe -m 5 http://192.168.56.102:3001` → `Connection timed
    out` en 3001 y 3002 (nadie escucha ahí en la IP externa y UFW descarta en silencio).
18. **Volumen frente a capa del contenedor**: lo escrito dentro del contenedor se pierde al recrearlo (el nuevo
    arranca limpio desde la imagen); lo que está en un volumen (gestionado por Docker fuera del contenedor,
    montado en `/datos`) sobrevive. `docker compose -p … exec web sh` abre una shell dentro del contenedor
    (prompt `/web #`): `hostname` devuelve el ID del contenedor y `ls /` muestra el Alpine de la imagen, no la VM.
    Guardado `dato DEV` y `dato PRUEBAS` en `/datos/prueba.txt` de cada uno.
19. **Etiquetas de versión (`dev-1` → `dev-2`)**: reconstruir con la misma etiqueta deja la imagen vieja como
    `<none>` (no sabes qué versión corre ni vuelves atrás fácil). Con etiqueta nueva conviven las dos y volver
    atrás es poner `TAG=dev-1` y `up -d`. En empresas suele ser la versión o el commit de Git.
20. **`git pull` no toca `.env`**: actualiza `.env.example` (está en Git), pero el `.env` local de cada servidor
    hay que cambiarlo a mano. La configuración local es responsabilidad de quien administra el servidor.
21. **Recrear conserva el volumen**: DEV se recreó al cambiar de imagen (ID nuevo `a5ddf81ad7dc`, antes
    `34943ffa3c5a`; Compose puso `Started`, no `Recreated`) y PRUEBAS con `--force-recreate` sin cambiar nada; en
    los dos el dato de `/datos` siguió ahí. PRUEBAS no se tocó al cambiar DEV (seguía "creado hace 2 horas").
    `dev-1` perdió la `U` (ningún contenedor la usa) pero sigue disponible para volver atrás.
22. **`down` frente a `down -v`**: `down` borra contenedores y red pero conserva los volúmenes; `down -v` también
    borra los volúmenes, es decir, los datos. Nunca sin estar seguro y sin copia.

## Día 4 · Viernes 16
1. **DNS y systemd-resolved**: el DNS traduce nombres a IPs. En Ubuntu los programas preguntan a un resolutor
   local (`nameserver 127.0.0.53`, el `127.0.0.53:53` que salía en `ss`), y este pregunta a los DNS reales que da
   el NAT de VirtualBox (`100.100.1.1`, `100.90.1.1`, `192.168.56.10`). Esas mismas IPs son las rutas "raras"
   `… via 10.0.2.2` que salían en `ip route`: el DHCP del NAT añade una ruta para llegar a cada DNS.
   `resolvectl query ubuntu.com` → 14 direcciones (IPv4 e IPv6) en 52,7 ms. `getent hosts dev.abaco.test` no
   devuelve nada: ese nombre solo existe en el `hosts` del PC (nos saltamos el DNS), por eso en la VM se usa
   `curl -H "Host: …"`. En la tabla del recorrido: IP, puerta de enlace, DNS, puerto y HTTP quedan cubiertos.
2. **`compose config` de los dos proyectos**: el PDF pedía validar ambos; el jueves solo se hizo DEV. Revisar
   el checklist contra lo hecho antes de dar algo por terminado.
3. **Línea base**: foto del estado antes de tocar nada (servicios, carga, RAM, disco, puertos, logs) para
   comparar cuando algo falle y ver qué cambió. Lo primero al llegar a un servidor.
4. **Leer los recursos**: load average = carga media de 1/5/15 min (con 2 vCPU, menos de 2 es holgado); en
   `top`, `id` = % de CPU libre; en `free -h` importa `available` (Linux usa la RAM sobrante como caché
   `buff/cache` y la libera cuando hace falta); `df -h` el % usado (19 % → 21 % por las imágenes de Docker).
5. **`sudo ss -lntp` y `docker-proxy`**: con sudo aparece qué proceso escucha. `docker-proxy` es el programa de
   Docker que reenvía `127.0.0.1:3001` al contenedor (`172.18.0.2:8080`).
6. **Leer `journalctl -p warning -b`**: no todo aviso es un problema; se clasifica (inofensivo, esperado,
   vigilar). Ahí apareció la prueba de seguridad del jueves: `[UFW BLOCK] SRC=192.168.56.20 … DPT=3001/3002`,
   la prueba de que el timeout lo causó UFW descartando los paquetes.
7. **Redes de Docker por proyecto**: en los logs del contenedor el origen es `172.18.0.1` (DEV) y `172.19.0.1`
   (PRUEBAS), la puerta de enlace de la red de cada proyecto, no la IP del PC: el contenedor solo ve a quien
   le reenvía (por eso Nginx añade `X-Real-IP`). Cada proyecto tiene su propia red: separación también en red.
   `HTTP/1.0`: Nginx habla al backend en HTTP/1.0 por defecto.
8. **`uptime` y VM pausada**: arrancó el 15 a las 12:36 pero `uptime` marca 15 h y `uptime -s` dice 16 a las
   00:14: con el PC suspendido la VM estuvo pausada y `uptime` no cuenta ese tiempo; al reanudar, NTP corrigió
   la hora (`Clock change detected`). Contrastar fuentes (journal, `systemctl status`) antes de fiarse de una.
9. **Qué hace buena a una copia**: coherente (sin escrituras mientras se copia), verificable (hash), fuera del
   servidor (el snapshot no lo es) y probada (restaurada y comparada). "Una copia solo queda demostrada cuando
   has restaurado y validado su contenido" (PDF).
10. **`tar` con `-C /` y rutas relativas**: `-c` crear, `-z` gzip, `-f` archivo, `-t` listar sin extraer, `-v`
    detalle. Con `-C /` y rutas sin `/` delante el archivo guarda rutas relativas: al restaurar se extrae donde
    elijas (`-C carpeta`) y no encima de `/etc` por accidente. Se incluyen los `.env`, que solo existen en la VM.
11. **Copia de un volumen (método de Docker)**: `compose stop` (sin escrituras) → contenedor temporal
    `docker run --rm -v abaco-dev_datos:/datos:ro -v ~/backups:/backup alpine:3.20 tar -czf … -C /datos .`
    (`--rm` se borra al acabar, `:ro` solo lectura) → `compose start`. Mientras DEV está parado, el sitio da 502:
    es la **ventana de corte**, que en producción se planifica. `stop`/`start` no recrea: el contenedor seguía
    "creado hace 23 horas". `prueba.txt` = 9 bytes (`dato DEV` + salto de línea).
12. **`sha256sum` y `tee`**: huella del archivo; si cambia un bit, cambia entera. `tee` muestra y guarda a la vez
    (`SHA256SUMS`). Los `.tar.gz` son de root (creados con `sudo`) pero legibles (644).
13. **`scp`**: copia archivos por SSH (misma clave y cifrado). Con comillas (`"…:backups/*"`) el `*` lo resuelve
    la VM; sin `/` delante la ruta es relativa al home remoto. Mismo hash en el PC (Windows en mayúsculas) =
    copia intacta. `sha256sum -c SHA256SUMS` lo comprueba de golpe.
14. **Restaurar desde la copia de fuera y en otra ubicación**: se restauró desde la copia del PC (simula perder
    el servidor) en `~/restore-test` y en un volumen nuevo `abaco-dev_restore`, sin tocar los originales.
    `tar -x … -C carpeta` extrae donde digas (la carpeta debe existir). `diff -r` sin salida = idénticos;
    `&& echo` solo se ejecuta si el comando anterior fue bien (código 0).
15. **Validar el funcionamiento, no solo el archivo**: un contenedor temporal con la imagen de DEV y el volumen
    restaurado (`127.0.0.1:3091`) sirvió la web y leyó `dato DEV`, igual que el original. Luego `docker rm -f`.
16. **Método de diagnóstico**: síntoma → evidencias → hipótesis → corrección → verificación, eslabón a eslabón
    y comparando con la línea base. Aunque sepamos qué hemos roto, se diagnostica como si no se supiera.
17. **Refused frente a timeout**: *connection refused* = el paquete llega pero nadie escucha en ese puerto (el
    sistema contesta con un rechazo, RST); *timeout* = el cortafuegos tira el paquete y no llega respuesta. Con
    Nginx parado: `ERR_CONNECTION_REFUSED`; el jueves, contra el 3001 desde el PC: timeout (UFW). En Windows el
    rechazo tarda unos 2 s (`after 2018 ms`) porque reintenta el SYN antes de rendirse.
18. **`stop` frente a `disable`**: `stop` para el servicio ahora, pero sigue `enabled` y arrancaría al
    reiniciar; `disable` quita el arranque automático. `status=0/SUCCESS` + `Deactivated successfully` = parada
    ordenada, no una caída (sería `failed` con otro código). `journalctl -u nginx` dice cuándo pasó.
19. **Aislar el eslabón**: `curl http://127.0.0.1:3001` → `200` demuestra que el contenedor funciona; el fallo
    está solo en Nginx. Probar cada pieza por separado acota dónde está el problema.
20. **502 Bad Gateway**: Nginx funciona y responde (`Server: nginx`), pero no consigue hablar con el backend.
    Al revés que el fallo A, donde no respondía nadie. El `error.log` del sitio da el upstream exacto
    (`connect() failed (111: Connection refused) … upstream: "http://127.0.0.1:3009/"`).
21. **`nginx -t` solo valida la sintaxis**: con `proxy_pass` a un puerto vacío dijo `test is successful`.
    "OK" no significa "funciona"; la prueba real es pedir la página.
22. **Comparar con el original**: `diff` repo ↔ `/etc` encuentra el cambio exacto, y restaurar es copiar el
    original (`cp` + `nginx -t` + `reload`). Por eso se conservan los originales. El `diff` enseñó además que
    `sed` había cambiado también el comentario de la línea 2.
23. **RCA**: resumen, impacto (qué, cuánto tiempo, a quién), cronología con horas de los logs, detección,
    evidencias, causa raíz, corrección y prevención. Los logs de accesos dan la duración exacta (17:32:25 →
    17:36:41). Ojo: la cabecera HTTP `Date` va en GMT y los logs en CEST (+2 h).
24. **Reinicio de comprobación**: un servidor tiene que volver solo. Lo garantizan `enabled` en systemd (Nginx,
    Docker, SSH), `restart: unless-stopped` en Compose (contenedores) y los volúmenes (datos fuera del
    contenedor). Tras `sudo reboot` (17:46:04): SSH con clave, root rechazado, servicios `active`, contenedores
    `Up`, `dato DEV`/`dato PRUEBAS` y `200`/`200`. `sudo` volvió a pedir contraseña: su caché no sobrevive al
    reinicio.

### Errores y problemas del día 4
| # | Qué pasó | Causa | Lección |
|---|---|---|---|
| 1 | `tar` de la configuración: `-bash: home/samiabaco/abaco-lab/docker: No such file or directory` y archivo de solo 532 bytes con 2 archivos | La línea, muy larga, se pegó partida en dos: `tar` se ejecutó sin la última ruta y bash intentó ejecutar la ruta como si fuera un comando (de ahí el error de `-bash`, no de `tar`). La carpeta sí existía (comprobado por SSH) | Leer **quién** da el error (`-bash:` frente a `tar:`). Comprobar justo después (`tar -tzvf` y tamaño). Comandos más cortos y una línea por bloque, marcada con ▶. Evidencia: `dia4/09a` |
| 2 | Los 3 comandos de restaurar la configuración (`tar -xzf … -C ~/restore-test/config` y los dos `diff`) → `No such file or directory` | La carpeta se creó como `confi` (faltó la última letra al pegar `mkdir -p ~/restore-test/config`). `tar -C` no crea la carpeta destino, así que falló, y los `diff` no encontraron nada que comparar | Un error al principio arrastra a los siguientes: arreglar el primero (`mv confi config`). Comprobar con `ls` que lo creado se llama como debe |
| 3 | `^[[200~sudo ss -lntp \| grep ':80 '~` → `sudo: command not found` | Al pegar, la marca de "pegado entre corchetes" (`ESC[200~ … ESC[201~`, con la que el terminal avisa a bash de que el texto es pegado) se coló como texto: la línea empezaba por `^[[200~sudo` y bash buscó un programa con ese nombre | Si aparece `^[[200~` al principio, la línea no es la que se pegó: borrarla y volver a pegarla (o escribirla). Al repetirlo salió bien. Evidencia: `dia4/20` |
| 4 | `curl.exe -s -o NUL …` → `curl.exe: command not found` (dos veces) | Era un comando de **PC** tecleado en la sesión de la **VM**: `curl.exe` es el nombre en Windows; en Linux es `curl` | Mirar el prompt antes de pegar (`samiabaco@abacolab` = VM, `PS C:\…>` = PC) y el `▶ VM`/`▶ PC` del paso. Repetido en PowerShell: `200` y `200`. Evidencia: `dia4/26a-26b` |

## Hallazgos de interés (para el tutor)
Cosas que no pedía el PDF pero que aparecieron al mirar con detalle, con su evidencia:
| Día | Hallazgo | Evidencia |
|---|---|---|
| 1 | `ubuntu-lv` venía con la mitad del disco (18,5 GB); ampliado en el instalador | `dia1/01` |
| 1-2 | `50-cloud-init.conf` (`PasswordAuthentication yes`) anulaba nuestro `99-abaco.conf`: en sshd gana el primer valor | `dia1/08`, `instalacion.md` |
| 1 | En Ubuntu 24.04 SSH arranca bajo demanda (`ssh.socket`): `ssh.service` sale `disabled` y aun así funciona | `instalacion.md` §6 |
| 2 | Los sitios daban la página por defecto: `localhost` va primero por IPv6 y faltaba `listen [::]:80;` | `dia2/07-09` |
| 2 | Un `200` puede venir del sitio equivocado: el tamaño (615 frente a 62 bytes) lo delató | `dia2/16-17` |
| 3 | Un contenedor es un proceso más de la VM (`pgrep` lo muestra) | `notas` día 3, lección 14 |
| 3 | Docker se salta UFW si publica en todas las interfaces; por eso `127.0.0.1:` en `ports` | `dia3/17` |
| 4 | Las rutas "raras" `… via 10.0.2.2` de `ip route` son las de los DNS que da el NAT | `dia2/15`, `dia4/02` |
| 4 | El `journal` guarda la prueba de seguridad del jueves: `[UFW BLOCK] SRC=192.168.56.20 … DPT=3001/3002` | `dia4/07` |
| 4 | Cada proyecto Compose tiene su propia red (`172.18.0.1` DEV, `172.19.0.1` PRUEBAS) | `dia4/08` |
| 4 | `compose stop` de DEV tardó 10,4 s: Python es el PID 1 del contenedor y el PID 1 ignora `SIGTERM` si no lo gestiona, así que Docker espera los 10 s de gracia y lo mata con `SIGKILL`. Mejora posible: `init: true` en el compose o `STOPSIGNAL SIGINT` en el Dockerfile (no aplicada) | `dia4/10` |
| 4 | La copia se restauró desde el PC (no desde la VM) y se validó con un contenedor que la usa: se demuestra que sirve, no solo que existe | `dia4/14-16`, `backup-restore.md` |
| 4 | `uptime` no cuenta el tiempo con la VM pausada (PC suspendido): 15 h frente a ~27 h reales | `dia4/04`, `incidencia-rca.md` §1 |
| 4 | En Windows una conexión rechazada tarda ~2 s (`after 2018 ms`): reintenta el SYN tras el RST. Refused (Nginx parado) ≠ timeout (UFW, jueves); el navegador lo dice claro: `ERR_CONNECTION_REFUSED` | `dia4/18-19` |
| 4 | Con Nginx parado, el contenedor seguía dando `200` en `127.0.0.1:3001`: el fallo era de un solo eslabón | `dia4/20` |
| 4 | `nginx -t` dio `test is successful` con `proxy_pass` a un puerto vacío: valida sintaxis, no que el destino exista | `dia4/22` |
| 4 | `sed` cambió también el comentario de la línea 2; solo el `diff` con el original lo mostró | `dia4/25` |
| 4 | La cabecera HTTP `Date` va en GMT (15:32:25) y los logs de Nginx en CEST (17:32:25): misma hora, 2 h de diferencia | `dia4/23`, `dev.access.log` |
| 4 | Con `dev.access.log` se mide la caída exacta del fallo B: 17:32:25 → 17:36:41 (~4 min, 2 peticiones fallidas) | `incidencia-rca.md` §4 |
| 4 | Tras el reinicio final todo volvió solo (SSH, Nginx, Docker, contenedores, datos, UFW). Ubuntu ofrece `26.04.1 LTS`: no se actualiza, el plan pide 24.04 | `dia4/27a-29`, `incidencia-rca.md` §5 |
| S2 | Una VM restaurada desde estado guardado da un `uptime -s` engañoso (11:28 de hoy) mientras los contenedores llevan `Up 2 days`: no hubo reinicio | `continuacion/01-02` |

### Errores y problemas del día 3
| # | Qué pasó | Causa | Lección |
|---|---|---|---|
| 1 | `curl -i -I "host: dev.abaco.test" http://localhost` → `Malformed input to a URL` y luego `200` | Faltaba `-H`: curl tomó `"host: …"` como URL y pidió `localhost` sin cabecera `Host`; respondió el sitio por defecto | Un 200 no basta: mirar **qué** respondió (`Content-Length` 615 = página por defecto, 62 = DEV) |
| 2 | `ping 192.168.56.20` → 100 % de pérdida | El firewall de Windows bloquea el ping | Un ping fallido no siempre es falta de red: SSH funciona por esa misma red |
| 3 | `docker ps` → `permission denied … docker.sock` (provocado a propósito) | El socket es `root:docker` y samiabaco no está en el grupo `docker` | Es la barrera que queremos: usar `sudo docker` (ver lección 5) |
| 4 | `ç: command not found` | Tecla suelta | Sin importancia; leer el error antes de seguir |
| 5 | Anuncié que `FROM` saldría `CACHED` y salió `CACHED [2/3] WORKDIR` | `FROM` no se marca como `CACHED`; la señal de reutilización es que no hay descarga (`extracting`) y el tiempo baja | Comprobar la salida real en vez de lo esperado |

## Continuación · Lunes 19 (semana 2)
1. **Referencia antes de cambiar nada**: el PDF pide demostrar al final que DEV y PRUEBAS "siguen igual"; solo se
   puede si antes se apunta cómo están (servicios, sitios activos, proyectos, imágenes, puertos, volúmenes, datos y
   lo que ve el cliente: código **y** marcador). Queda en `continuacion/README.md` §1.
2. **VM restaurada desde estado guardado**: `uptime -s` dio 11:28 de hoy, pero los contenedores marcaban
   `Up 2 days`. Al restaurar, el reloj se pone en hora y el contador de tiempo encendido sigue donde estaba, así
   que la hora de "arranque" calculada sale desplazada. No hubo reinicio. Evidencias `continuacion/01-02`.
3. **Comprobar que lo nuevo no choca**: puerto libre (`ss -ltn`), nombre de proyecto libre (`compose ls -a`:
   `-a` incluye proyectos parados, que siguen teniendo contenedores y volúmenes), imagen, sitio de Nginx y carpeta.
   Si `abaco-ensayo` ya existiera, Compose reutilizaría sus recursos y se podrían pisar datos.

### Errores y problemas de la continuación
| # | Qué pasó | Causa | Lección |
|---|---|---|---|
| 1 | Tras pegar `ss -ltn \| grep -E ':301[12]' \|\| echo "…"` el prompt pasó a `>` y el siguiente comando no hizo nada | Al pegar quedó una comilla sin cerrar: `>` es el prompt de continuación de bash, que espera el cierre y toma todo lo escrito como texto | Si aparece `>`, **Ctrl+C** y repetir. Preferir comandos sin comillas (`ss -ltn | grep :30`)\| grep 301`) |
| 2 | `ss -ltn \| grep 301` no devolvió nada, cuando se esperaba ver 3001 y 3002 | Error del filtro que propuse: "301" no está dentro de "3001" (3-0-0-1); solo encontraría 3010-3019. Por SSH se vio que 3001 y 3002 sí escuchan | Un `grep` vacío puede significar "no está" o "el filtro está mal": probar que encuentra lo que **sí** debe estar (`grep :30` → 3001 y 3002, y ningún 3011/3012) |
