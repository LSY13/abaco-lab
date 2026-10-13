# abaco-lab

Laboratorio de la formación en servidores de Abaco (13-16 de octubre de 2026): Ubuntu Server 24.04, SSH,
Nginx y Docker Compose sobre una VM de VirtualBox.

## Estado
| Día | Tema | Estado |
|---|---|---|
| Mar 13 | Instalar Ubuntu, SSH con clave y UFW | ✅ Hecho ([instalacion.md](documentacion/instalacion.md)) · falta "qué he aprendido" |
| Mié 14 | Nginx: dos sitios y proxy inverso | ⏳ |
| Jue 15 | Docker Compose: DEV y PRUEBAS separados | ⏳ |
| Vie 16 | Copias, restauración, diagnóstico y RCA | ⏳ |

## Mapa
```
[ PC Windows 192.168.56.20 ] --(solo-anfitrión)--> [ VM abacolab 192.168.56.102 ]
                                                        |
                                                      (NAT) --> Internet
```

## Estructura
- `documentacion/`: instalación, despliegue, backup/restore y RCA
- `nginx/`, `docker/`: configuraciones
- `evidencias/diaN/`: salidas y capturas de cada día

La guía completa para repetir el laboratorio se completará el viernes 16.
