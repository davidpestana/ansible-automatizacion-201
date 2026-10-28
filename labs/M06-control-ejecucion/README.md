# M06 — Control de ejecución

[← Página anterior](../M05-modularizacion/03-buenas-practicas.md) · [Siguiente página →](00-flujo-de-una-ejecucion.md)

Un playbook no siempre hace lo mismo, en el mismo orden y en todos los nodos. Hay tareas que solo tocan en
producción, otras que se repiten por cada usuario o paquete de una lista, acciones que solo deben ocurrir si
algo ha cambiado (recargar un servicio), partes que se quieren lanzar por separado y comprobaciones cuyo
resultado decide si se sigue. Este módulo cubre las herramientas de Ansible para controlar la ejecución:
condicionales, bucles, handlers, tags y el registro de resultados.

## Qué aprenderás

- Decidir si una tarea se ejecuta según una variable de entorno, el grupo del nodo o un fact del sistema.
- Recorrer listas de usuarios y paquetes con `loop`, y combinarlo con `when` para filtrar elemento a elemento.
- Recargar un servicio solo cuando cambia su configuración, una sola vez por ejecución, con `notify` y `handlers`.
- Lanzar solo una parte de un proyecto (`--tags config`, `--skip-tags paquetes`) sin tocar el resto.
- Guardar la salida de una comprobación con `register`, decidir con ella y fallar a tiempo con `failed_when`.

## Teoría

### Las preguntas de cada tarea

| Pregunta | Palabra clave | Ejemplo |
|----------|---------------|---------|
| ¿Se ejecuta en este nodo? | `when` | Un aviso en `/etc/motd` solo si `entorno == 'prod'` |
| ¿Cuántas veces? | `loop` | Una vez por cada usuario de una lista |
| ¿Qué pasa si cambia algo? | `notify` + `handlers` | Si cambia la configuración de nginx, `Recargar nginx` al final |
| ¿Entra en esta ejecución? | `tags` | `--tags config` aplica solo las tareas de configuración |
| ¿Qué ha devuelto? | `register`, `changed_when`, `failed_when` | La respuesta de una comprobación decide si la tarea pasa |

### Con qué se puede decidir

`when` recibe una expresión Jinja2 **sin** llaves `{{ }}`. Lo que cabe dentro es cualquier variable que Ansible
conozca en ese nodo:

| Origen | Ejemplo | Para qué |
|--------|---------|----------|
| Variable de inventario | `entorno == 'prod'` | Lo que solo se hace en producción |
| Fact | `ansible_facts['distribution'] == 'Debian'` | Usar `apt` solo donde hay `apt` |
| Grupos del inventario | `inventory_hostname in groups['webservers']` | Lo que solo necesitan los servidores web |
| Elemento del bucle | `entorno in item.entornos` | Cada elemento, solo donde corresponde |
| Resultado registrado | `comprobacion.rc == 0` | Seguir solo si la comprobación anterior funcionó |

> [!NOTE]
> Con `loop`, el `when` se evalúa **por elemento**, no una vez para toda la tarea. Por eso la misma tarea puede
> crear dos usuarios y saltarse un tercero en el mismo nodo.

### Handler o tarea con `when`

| | Tarea con `register` + `when: … is changed` | Handler |
|---|---|---|
| Dónde se escribe | Entre las tareas, en su sitio | En `handlers:` del play o `handlers/main.yml` del rol |
| Cuándo corre | Justo donde está | Al final de la sección (o en `meta: flush_handlers`) |
| Si lo piden tres tareas | Hay que combinar tres registros en el `when` | Corre una vez |
| Si nadie cambia nada | Aparece como `skipping` | Ni aparece en la salida |

> [!NOTE]
> Un handler corre **una vez por nodo** y al final, aunque lo notifiquen varias tareas. Si una tarea posterior
> falla, los handlers pendientes de ese nodo no corren, salvo con `--force-handlers`.

### Tags: elegir qué entra en la ejecución

Los tags no cambian lo que hace una tarea: solo dicen si entra en esta ejecución. Un reparto habitual es por
fase: `paquetes`, `config`, `despliegue`. Dos tags tienen significado propio: `always` entra siempre salvo que se
salte a propósito, y `never` no entra nunca salvo que se pida por su otro tag.

> [!NOTE]
> `changed_when` y `failed_when` no cambian lo que hace la tarea, sino cómo se informa: una consulta como
> `nginx -v` no cambia nada en el nodo, así que no debe salir como `changed`.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [El flujo de una ejecución](00-flujo-de-una-ejecucion.md) | Demostración: when, loop y handlers en una misma ejecución del portal |
| 01 | [Lab — Lógica condicional](01-lab-condicionales-y-bucles.md) | Decides tareas según el nodo y el entorno y recorres listas de usuarios y paquetes |
| 02 | [Lab — Handlers](02-lab-handlers.md) | Recargas nginx solo cuando cambia su configuración |
| 03 | [Lab — Tags](03-lab-tags.md) | Ejecutas o saltas solo una parte del playbook |
| 04 | [Lab — Registro de resultados](04-lab-registro-de-resultados.md) | Usas la salida de una comprobación para decidir y para fallar a tiempo |

→ Empieza por **[00 — El flujo de una ejecución](00-flujo-de-una-ejecucion.md)**.
<!-- /gen:paginas -->
