# M08 — Operaciones de día 2

[← Página anterior](../M07-despliegues/03-lab-despliegue-escalonado.md) · [Siguiente página →](00-cambios-controlados.md)

Las operaciones de «día 2» son todo lo que viene después de la instalación y el primer despliegue: aplicar
parches, atender peticiones de cambio en producción y diagnosticar lo que falla. Con Ansible, ese trabajo diario
gana una red de seguridad: simular antes de tocar, probar en un nodo y extender al resto, con el cambio escrito y
revisable. Este módulo cubre la actualización y el parcheo, los cambios controlados y el troubleshooting de
ejecuciones que fallan.

## Qué aprenderás

- Llevar una petición de cambio a producción sin sorpresas: `--check --diff` para ver qué cambiaría, `--limit` para
  aplicarlo primero en un nodo canario y `backup: true` para tener la vuelta atrás a mano.
- Parchear servidores de uno en uno, con un informe de lo pendiente antes de tocar nada y una verificación del
  servicio después.
- Leer lo que el modo check no ve (las validaciones, los comandos) y aprovechar el canario para que un error se
  quede en un solo nodo.
- Diagnosticar fallos reales: un nodo caído, una variable mal escrita, un permiso que falta o una configuración
  rota, con `-vvv`, `ansible.builtin.debug`, `--start-at-task`, `--step` y las validaciones del propio servicio.

## Teoría

### El ciclo de un cambio en producción

| Paso | Comando o recurso | Qué responde |
|------|-------------------|--------------|
| Simular | `ansible-playbook … --check --diff` | Qué tareas cambiarían y qué líneas de cada fichero |
| Acotar | `--tags config`, `--limit web1` | Solo la parte del playbook y el nodo que toca |
| Canario | `ansible-playbook … --limit web1` | Si el cambio funciona de verdad en un nodo |
| Comprobar | `curl`, `ansible … -m ansible.builtin.command` | Si el servicio sigue respondiendo y el valor es el esperado |
| Extender | `ansible-playbook …` sin `--limit` | El resto del grupo; el canario sale `changed=0` |
| Volver atrás | `backup: true`, Git | El fichero anterior en el nodo y el cambio anterior en el repositorio |

> [!NOTE]
> `--check` no es una prueba completa. Los módulos simulan lo que harían, pero no ejecutan comandos
> (`ansible.builtin.command` sale `skipping`) ni la validación `validate:` de una plantilla. Un valor que el
> servicio rechazaría aparece en el diff como un cambio más. Por eso después del check viene el canario.

### Parcheo

| Opción de `ansible.builtin.apt` | Equivale a | Cuándo |
|---------------------------------|------------|--------|
| `update_cache: true` | `apt-get update` | Siempre antes de mirar o aplicar actualizaciones |
| `upgrade: safe` | `apt-get upgrade` sin quitar paquetes | Parcheo habitual |
| `upgrade: dist` | `apt-get dist-upgrade` | Cambios de dependencias; con más cuidado |
| `name: "*"` + `state: latest` | Actualizar todo lo instalado | Alternativa a `upgrade` |

Los servidores que están detrás de un balanceador se parchean con `serial: 1`: mientras uno se actualiza, los
demás atienden. Si el sistema deja `/var/run/reboot-required` (pasa tras actualizar el núcleo o la libc), se
reinicia con `ansible.builtin.reboot`, que espera a que el nodo vuelva. En distribuciones de la familia Red Hat
el módulo equivalente es `ansible.builtin.dnf`.

### Leer un fallo

| Lo que dice el `PLAY RECAP` | Qué ha pasado | Por dónde empezar |
|-----------------------------|---------------|-------------------|
| `unreachable=1` | Ansible no llega al nodo por SSH | ¿Está encendido? `ansible … -m ansible.builtin.ping`, `-vvv` |
| `failed=1` | Ha llegado, pero una tarea ha fallado | El mensaje `[ERROR]` y su `Origin: fichero:línea` |
| `changed` donde no esperabas | Alguien ha tocado el nodo a mano (deriva) | `--check --diff` |

> [!TIP]
> `-v` añade el resultado de cada tarea, `-vvv` la conexión SSH y cada comando que Ansible lanza en el nodo.
> Con `ANSIBLE_KEEP_REMOTE_FILES=1` Ansible no borra en el nodo los ficheros temporales del módulo, para
> examinarlos a mano; se usa poco y solo mientras se depura.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Cambios controlados](00-cambios-controlados.md) | Demostración: de la petición al cambio aplicado, con check, diff, canario y backup |
| 01 | [Lab — Parcheo](01-lab-parcheo.md) | Detectas actualizaciones pendientes y parcheas los nodos de prod de uno en uno |
| 02 | [Lab — Cambio en producción](02-lab-cambio-en-produccion.md) | Simulas un cambio en prod, lo aplicas a un canario y luego al resto |
| 03 | [Lab — Troubleshooting](03-lab-troubleshooting.md) | Diagnosticas ejecuciones que fallan con -vvv, debug y --start-at-task |

→ Empieza por **[00 — Cambios controlados](00-cambios-controlados.md)**.
<!-- /gen:paginas -->
