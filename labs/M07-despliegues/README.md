# M07 — Despliegues con Ansible

[← Página anterior](../M06-control-ejecucion/04-lab-registro-de-resultados.md) · [Siguiente página →](00-anatomia-de-un-despliegue.md)

Automatizar un despliegue es más que copiar ficheros en los servidores: hay que publicar la versión nueva sin
pisar la anterior, cambiar de una a otra en un solo paso, verificar que el servicio responde y, si no lo hace,
volver atrás sin intervención manual. Este módulo cubre el despliegue por releases versionadas, la ejecución
sobre múltiples nodos (patrones, `--limit`, `forks`) y las estrategias básicas: todos a la vez, por tandas y por
tandas con vuelta atrás automática.

## Qué aprenderás

- Publicar una release nueva de una aplicación en varios nodos y comprobarla desde el terminal con `curl`.
- Elegir sobre qué nodos actúa cada ejecución con patrones, `--limit` y `--list-hosts`, y cuántos a la vez con `forks`.
- Desplegar por tandas con `serial`, parar a la primera señal de error con `max_fail_percentage` y volver a la
  release anterior sin intervención manual.

## Teoría

### Despliegue por releases

Cada versión de la aplicación vive en su propia carpeta y un enlace simbólico dice cuál se sirve:

```text
/srv/app/
├── current -> /srv/app/releases/1.1.0     ← lo que sirve el servidor web (root /srv/app/current)
└── releases/
    ├── 1.0.0/
    └── 1.1.0/
```

| Pieza | Qué hace | Cómo se hace con Ansible |
|-------|----------|--------------------------|
| Carpeta de la release | Guarda la versión completa, sin pisar las anteriores | `ansible.builtin.file` (`state: directory`) + `copy`, `unarchive` o `git` |
| Enlace `current` | Cambia de versión en un solo paso | `ansible.builtin.file` con `state: link` |
| Verificación | Confirma que el servicio responde tras el cambio | `ansible.builtin.uri` con `status_code` y, si hace falta, el contenido |

Volver atrás es solo apuntar `current` a la carpeta anterior: la release vieja sigue en el disco.

> [!NOTE]
> Que Ansible termine con `failed=0` no significa que el servicio funcione. Una release a la que le falta un
> fichero se copia sin errores y, sin embargo, el servidor web responde 403 o 404. Por eso un despliegue acaba
> siempre con una verificación del servicio, no solo de las tareas.

### Sobre qué nodos y cuántos a la vez

| Mecanismo | Dónde se pone | Qué decide | Ejemplo |
|-----------|---------------|------------|---------|
| Patrón de hosts | `hosts:` del play o argumento de `ansible` | Qué nodos entran | `webservers`, `web*`, `webservers:!web2`, `all:!dbservers` |
| `--limit` | Línea de comandos | Recorta el patrón del play sin editarlo | `--limit web1` |
| `--list-hosts` | Línea de comandos | Enseña los nodos sin ejecutar nada | `ansible-playbook site.yml --list-hosts` |
| `forks` | `-f` o `ansible.cfg` (por defecto 5) | Cuántos nodos trabajan a la vez **en cada tarea** | `-f 1` |
| `serial` | Play | Cuántos nodos hacen **el play entero** antes de pasar a los siguientes | `serial: 1` |
| `max_fail_percentage` | Play | Qué porcentaje de fallos en una tanda detiene el resto | `max_fail_percentage: 0` |

> [!NOTE]
> `forks` y `serial` se confunden a menudo. Con `-f 1` cada tarea va nodo a nodo, pero **todos** los nodos
> reciben la tarea 1 antes de que nadie empiece la 2: si la release está rota, acaban rotos todos. Con
> `serial: 1`, el primer nodo hace el play completo (desplegar y verificar) antes de que el segundo empiece.

### Estrategias básicas

| Estrategia | Cómo se hace con Ansible | Qué pasa si la release está rota |
|------------|--------------------------|----------------------------------|
| Todos a la vez | Play sobre el grupo, sin `serial` | Caen todos los nodos a la vez: el servicio entero da error |
| Por tandas (*rolling*) | `serial: 1` (o `serial: "50%"`) | Cae el primer nodo; el balanceador sigue sirviendo con los demás |
| Por tandas con vuelta atrás | `serial` + `block`/`rescue` que restaura `current` + `max_fail_percentage: 0` | El primer nodo vuelve solo a la release anterior y el despliegue se para |

> [!TIP]
> Sacar el nodo del balanceador mientras se actualiza, para que ningún cliente vea el error, exige
> ejecutar tareas en otro nodo (`delegate_to`). Eso es orquestación y se trabaja en el M09.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Anatomía de un despliegue](00-anatomia-de-un-despliegue.md) | Demostración: releases versionadas, enlace current y verificación tras desplegar |
| 01 | [Lab — Despliegue completo](01-lab-despliegue-completo.md) | Despliegas una release del portal en prod con balanceador y la verificas |
| 02 | [Lab — Múltiples nodos](02-lab-multiples-nodos.md) | Eliges sobre qué nodos y cuántos a la vez con patrones, --limit y forks |
| 03 | [Lab — Despliegue escalonado](03-lab-despliegue-escalonado.md) | Actualizas por tandas, paras si falla y vuelves a la release anterior |

→ Empieza por **[00 — Anatomía de un despliegue](00-anatomia-de-un-despliegue.md)**.
<!-- /gen:paginas -->
