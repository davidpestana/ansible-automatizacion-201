# M06 — Control de ejecución

[← Página anterior](../M05-modularizacion/03-buenas-practicas.md) · [Siguiente página →](00-flujo-de-una-ejecucion.md)

Hasta ahora el rol `portal` hace siempre lo mismo, en el mismo orden, en todos los nodos. El runbook de
Tienda Norte no era así: «en producción, avisa al entrar por SSH», «crea las cuentas de Ana y Luis, pero la del
becario solo en dev», «recarga nginx si has tocado su configuración, y solo entonces», «si solo cambias la
configuración, no reinstales paquetes», «comprueba qué versión sirve el nodo antes de dar el trabajo por bueno».
Este módulo traslada esas decisiones al proyecto: qué se ejecuta, cuándo, cuántas veces y qué se hace con el
resultado de cada tarea.

## Qué aprenderás

- Decidir si una tarea se ejecuta según el entorno (`portal_entorno`), el grupo del nodo o un fact del sistema.
- Recorrer listas de usuarios y paquetes con `loop`, y combinarlo con `when` para filtrar elemento a elemento.
- Recargar nginx solo cuando cambia su configuración, una sola vez por ejecución, con `notify` y `handlers`.
- Lanzar solo una parte del proyecto (`--tags config`, `--skip-tags paquetes`) sin tocar el resto.
- Guardar la salida de una comprobación con `register`, decidir con ella y fallar a tiempo con `failed_when`.

## Teoría

### Las preguntas de cada tarea

| Pregunta | Palabra clave | Ejemplo en el portal |
|----------|---------------|----------------------|
| ¿Se ejecuta en este nodo? | `when` | El aviso de `/etc/motd` solo si `portal_entorno == 'prod'` |
| ¿Cuántas veces? | `loop` | Una vez por usuario de operaciones: `ana`, `luis`, `becario` |
| ¿Qué pasa si cambia algo? | `notify` + `handlers` | Si cambia `nginx.conf` o el sitio, `Recargar nginx` al final |
| ¿Entra en esta ejecución? | `tags` | `--tags config` aplica solo la configuración de nginx |
| ¿Qué ha devuelto? | `register`, `changed_when`, `failed_when` | La versión que publica `estado.json` decide si la comprobación pasa |

### Con qué se puede decidir

`when` recibe una expresión Jinja2 **sin** llaves `{{ }}`. Lo que cabe dentro es cualquier variable que Ansible
conozca en ese nodo:

| Origen | Ejemplo | Para qué en Tienda Norte |
|--------|---------|--------------------------|
| Variable de inventario | `portal_entorno == 'prod'` | Lo que solo se hace en producción |
| Fact | `ansible_facts['distribution'] == 'Debian'` | Usar `apt` solo donde hay `apt` |
| Grupos del inventario | `inventory_hostname in groups['web']` | Lo que solo necesitan los servidores web |
| Elemento del bucle | `portal_entorno in item.entornos` | Cada usuario, solo en sus entornos |
| Resultado registrado | `comprobar_nginx.rc == 0` | Pedir `estado.json` solo si nginx está instalado |

> [!NOTE]
> Con `loop`, el `when` se evalúa **por elemento**, no una vez para toda la tarea. Por eso la misma tarea puede
> crear `ana` y `luis` en `prod-web1` y saltarse `becario` en el mismo nodo.

### Handler o tarea con `when`

| | Tarea con `register` + `when: … is changed` | Handler |
|---|---|---|
| Dónde se escribe | Entre las tareas, en su sitio | En `handlers/main.yml` del rol |
| Cuándo corre | Justo donde está | Al final de la sección (o en `meta: flush_handlers`) |
| Si lo piden tres tareas | Hay que combinar tres registros en el `when` | Corre una vez |
| Si nadie cambia nada | Aparece como `skipping` | Ni aparece en la salida |

> [!NOTE]
> Un handler corre **una vez por nodo** y al final, aunque lo notifiquen varias tareas. Si una tarea posterior
> falla, los handlers pendientes de ese nodo no corren, salvo con `--force-handlers`.

### Tags: elegir qué entra en la ejecución

Los tags no cambian lo que hace una tarea: solo dicen si entra en esta ejecución. En el proyecto del curso se
reparten así: `paquetes` (instalar nginx), `config` (plantillas y sitios de nginx), `despliegue` (la release del portal).
Dos tags tienen significado propio: `always` entra siempre salvo que se salte a propósito, y `never` no entra
nunca salvo que se pida por su otro tag.

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
