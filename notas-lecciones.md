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
