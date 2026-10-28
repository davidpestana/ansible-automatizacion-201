# M07 — Despliegues con Ansible

[← Página anterior](../M06-control-ejecucion/04-lab-registro-de-resultados.md) · [Siguiente página →](00-anatomia-de-un-despliegue.md)

En el runbook de Tienda Norte, «sacar una versión» era entrar por SSH en cada servidor web, copiar ficheros,
recargar nginx y mirar el navegador. Si algo salía mal a mitad, prod quedaba con un servidor en la versión nueva
y otro en la vieja, y volver atrás era repetir todo a mano. Este módulo convierte esa tarea en
**automatización de despliegues**: releases versionadas que se publican en todos los nodos de prod, se
verifican y, si fallan, se deshacen solas, nodo a nodo.

## Qué aprenderás

- Publicar una release nueva del portal en prod (balanceador y dos web) y comprobarla desde el terminal con `curl`.
- Elegir sobre qué nodos actúa cada ejecución con patrones, `--limit` y `--list-hosts`, y cuántos a la vez con `forks`.
- Desplegar por tandas con `serial`, parar a la primera señal de error con `max_fail_percentage` y volver a la
  release anterior sin intervención manual.

## Teoría

### Despliegue por releases

Cada versión del portal vive en su propia carpeta y un enlace simbólico dice cuál se sirve:

```text
/srv/portal/
├── current -> /srv/portal/releases/1.1.0     ← lo que sirve nginx (root /srv/portal/current)
└── releases/
    ├── 1.0.0/   index.html  estado.json
    └── 1.1.0/   index.html  estado.json
```

| Pieza | Qué hace | Tarea del rol `portal` (`tasks/desplegar.yml`) |
|-------|----------|------------------------------------------------|
| Carpeta de la release | Guarda la versión completa, sin pisar las anteriores | `Crear la carpeta de la release`, `Copiar la release …` |
| Enlace `current` | Cambia de versión en un solo paso | `Apuntar current a la release …` |
| `estado.json` | Dice qué host, entorno y versión responde | `Publicar el estado del nodo` |
| Verificación | Confirma que el portal responde tras el cambio | `ansible.builtin.uri` en `deploy.yml` |

Volver atrás es solo apuntar `current` a la carpeta anterior: la release vieja sigue en el disco. Como
`estado.json` está **dentro** de cada release, al cambiar el enlace también cambia la versión que publica el nodo.

> [!NOTE]
> Que Ansible termine con `failed=0` no significa que el portal funcione. La release 1.2.0 se copia sin errores
> y, sin embargo, nginx responde 403 porque le falta `index.html`. Por eso un despliegue acaba siempre con una
> verificación del servicio, no solo de las tareas.

### Sobre qué nodos y cuántos a la vez

| Mecanismo | Dónde se pone | Qué decide | Ejemplo en Tienda Norte |
|-----------|---------------|------------|-------------------------|
| Patrón de hosts | `hosts:` del play o argumento de `ansible` | Qué nodos entran | `web`, `prod-web*`, `web:!prod-web2`, `all:!db` |
| `--limit` | Línea de comandos | Recorta el patrón del play sin editarlo | `--limit prod-web1` |
| `--list-hosts` | Línea de comandos | Enseña los nodos sin ejecutar nada | `ansible-playbook site.yml --list-hosts` |
| `forks` | `-f` o `ansible.cfg` (por defecto 5) | Cuántos nodos trabajan a la vez **en cada tarea** | `-f 1` |
| `serial` | Play | Cuántos nodos hacen **el play entero** antes de pasar a los siguientes | `serial: 1` |
| `max_fail_percentage` | Play | Qué porcentaje de fallos en una tanda detiene el resto | `max_fail_percentage: 0` |

> [!NOTE]
> `forks` y `serial` se confunden a menudo. Con `-f 1` cada tarea va nodo a nodo, pero **todos** los nodos
> reciben la tarea 1 antes de que nadie empiece la 2: si la release está rota, acaban rotos los dos web.
> Con `serial: 1`, `prod-web1` hace el play completo (desplegar y verificar) antes de que `prod-web2` empiece.

### Estrategias básicas

| Estrategia | Cómo se hace con Ansible | Qué pasa si la release está rota |
|------------|--------------------------|----------------------------------|
| Todos a la vez | Play sobre `web`, sin `serial` | Caen los dos web a la vez: el portal entero da error |
| Por tandas (*rolling*) | `serial: 1` (o `serial: "50%"`) | Cae el primer nodo; el balanceador sigue sirviendo con el otro |
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
