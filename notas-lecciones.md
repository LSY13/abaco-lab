# Lecciones pendientes de apuntar con mis palabras

Lista de temas vistos. Al final del día escribo cada uno en `documentacion/instalacion.md`
(sección "Qué he aprendido") explicándolo yo.

## Día 1 · Martes 13
1. **Repositorio y .gitignore**: por qué la configuración se versiona y por qué los secretos nunca entran en Git.
2. **Markdown en vez de Word**: texto plano, Git ve los cambios línea a línea.
3. **Equipo físico, VM y VPS**: qué es un hipervisor y por qué no se le dan todos los recursos a la VM.
4. **Dos tarjetas de red**: NAT (salir a Internet) y solo-anfitrión (PC ↔ VM).
5. **10.0.2.x frente a 192.168.56.x**: dos redes distintas; para hablar hay que estar en la misma red; IPs privadas.
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
20. **Permisos `rwx` y numéricos (644/600/700, umask 664)**: el caso de `cat` denegado y `sudo cat` permitido.
21. **`sudo` y el principio de mínimo privilegio.**
22. **Leer los errores** (`chmode`, `ping -c 3` sin destino) y pedir ayuda con un error concreto.
23. **El prompt indica en qué máquina estás** (clave creada por error en la VM).
24. **Fingerprint y `known_hosts`.**
25. **Clave pública (candado) y privada (llave)**; `authorized_keys` y sus permisos.
26. **UFW**: denegar lo entrante por defecto, permitir 22 solo desde el PC, permitir antes de activar.
27. **`PermitRootLogin no`**, `sshd_config.d/`, `sudo tee`, `sshd -t` frente a `sshd -T`.
28. **Orden de los archivos en `sshd_config.d`** (gana el primer valor; el caso `50-cloud-init`). Pendiente para el miércoles.
29. **No cerrar la única sesión abierta** antes de probar otra.

## Día 2 · Miércoles 14
1. **`sshd_config.d`: gana el primer valor, no el último.** Nuestro `99-abaco.conf` se leía después de
   `50-cloud-init.conf` (`PasswordAuthentication yes`), así que nunca podía anularlo. Solución: renombrarlo a
   `10-abaco.conf` en vez de editar o borrar un archivo que no es nuestro. En otros programas gana el último:
   verificar siempre el valor efectivo (`sshd -T`).
2. **Archivo correcto ≠ servicio aplicándolo**: `sshd -t`/`-T` leen el disco; el servicio en marcha necesita
   `systemctl reload ssh` (relee sin cortar sesiones; `restart` para y arranca).
