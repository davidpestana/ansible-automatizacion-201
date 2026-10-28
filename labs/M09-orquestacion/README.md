# M09 — Orquestación

[← Página anterior](../M08-operaciones-dia-2/03-lab-troubleshooting.md) · [Siguiente página →](00-orden-del-portal.md)

El portal de pedidos de Tienda Norte ya no es un servidor: en prod son cuatro nodos que dependen unos de otros.
Las web necesitan la base de datos `prod-db1`, y el balanceador `prod-lb1` necesita las web. En el runbook manual
el orden lo llevaba la persona que tecleaba; en `proyecto/` lo tiene que llevar el propio proyecto. Este módulo
coordina base de datos, web y balanceador en el orden correcto, decide qué se hace en paralelo y qué de uno en uno,
y orquesta una actualización de las web sin que el portal deje de responder.

## Qué aprenderás

- Encadenar la base de datos, las web y el balanceador en `site.yml` con `import_playbook` y explicar qué se rompe
  si el orden cambia.
- Hacer explícita una dependencia: que las web esperen a que PostgreSQL acepte conexiones con
  `ansible.builtin.wait_for` antes de configurarse.
- Leer desde un play lo que otro play ha descubierto (`hostvars`, `groups['db'][0]`), ejecutar una tarea una sola
  vez con `run_once` y lanzarla en otro nodo con `delegate_to`.
- Elegir el ritmo de una ejecución: `forks`, `serial` (fijo o por lotes), `strategy: free` frente a `linear`, y
  tareas largas en segundo plano con `async`, `poll` y `ansible.builtin.async_status`.
- Actualizar las dos web de prod una a una, sacándolas del balanceador desde el propio playbook, mientras un bucle de
  `curl` comprueba que el portal no deja de contestar.

## Teoría

### Tres servicios, un orden

| Servicio | Nodo | Depende de | Si arranca antes de tiempo |
|----------|------|------------|-----------------------------|
| PostgreSQL | `prod-db1` | nada | — |
| Web (nginx + release) | `prod-web1`, `prod-web2` | `prod-db1` acepta conexiones en el 5432 | El portal publica `"db": "prod-db1"`, pero ahí no escucha nadie |
| Balanceador | `prod-lb1` | al menos una web responde en el 80 | `502 Bad Gateway` en el puerto 8080 |

Ansible ejecuta los plays de un playbook **en el orden en que están escritos**, y no empieza un play hasta que
termina el anterior. Por eso el orden del portal se expresa así:

```yaml
# proyecto/site.yml
- name: Base de datos
  ansible.builtin.import_playbook: db.yml
- name: Web
  ansible.builtin.import_playbook: web.yml
- name: Balanceador
  ansible.builtin.import_playbook: lb.yml
```

> [!NOTE]
> **Orden ≠ disponibilidad.** Que el play de la base de datos termine bien quiere decir que PostgreSQL está
> instalado y arrancado, no que ya acepte conexiones desde las web. Para eso está `ansible.builtin.wait_for`:
> convierte la dependencia en una comprobación que falla con un mensaje claro si no se cumple.

### Dependencias: orden de plays frente a `meta/main.yml`

| Mecanismo | Dónde se escribe | Qué hace | Cuándo usarlo |
|-----------|------------------|----------|---------------|
| Orden de plays | `site.yml` | Cada servicio se configura en **sus** nodos, uno detrás de otro | Servicios en nodos distintos: db → web → lb |
| `dependencies` en `meta/main.yml` | El rol | Ejecuta el rol dependiente **en los mismos nodos**, antes que el propio rol | Un rol que necesita otro en el mismo servidor (p. ej. un rol común de paquetes) |
| `ansible.builtin.wait_for` | Una tarea | Espera a que un puerto o un fichero estén listos | Comprobar que el servicio del que dependes responde |

> [!WARNING]
> Poner `portal_db` como dependencia del rol `portal` no hace que las web esperen a la base de datos: instala
> PostgreSQL **en las web**. Las dependencias entre nodos se resuelven con el orden de plays.

### Trabajar con otros nodos desde un play

| Herramienta | Para qué en el portal |
|-------------|-----------------------|
| `groups['db'][0]` | El nombre de la base de datos del inventario, sin escribirlo a mano |
| `hostvars['prod-db1']` | Variables, facts y registros de otro nodo, también de un play anterior |
| `run_once: true` | Una tarea que se hace una vez por ejecución (un aviso, una migración), no una por web |
| `delegate_to: prod-lb1` | La tarea se ejecuta en el balanceador, pero con las variables del nodo web que la lanza |

### El ritmo de una ejecución

| Ajuste | Dónde | Qué cambia |
|--------|-------|------------|
| `forks` | `ansible.cfg` o `-f N` | Cuántos nodos atiende Ansible a la vez (5 por defecto) |
| `serial: 1` | Play | El play entero se hace nodo a nodo: un lote, luego el siguiente |
| `serial: [1, "50%"]` | Play | Lotes crecientes: primero uno de prueba, luego la mitad, luego el resto |
| `strategy: linear` | Play (por defecto) | Cada tarea espera a que todos los nodos terminen la anterior |
| `strategy: free` | Play o `ANSIBLE_STRATEGY` | Cada nodo avanza a su ritmo, sin esperar a los demás |
| `async` + `poll: 0` | Tarea | La tarea sigue en el nodo en segundo plano; el play continúa |
| `ansible.builtin.async_status` | Tarea | Recoge el resultado de una tarea en segundo plano |

> [!NOTE]
> `serial` decide **cuántos nodos entran en el play** a la vez; `forks` decide **cuántas conexiones** abre Ansible.
> Con `serial: 1` da igual tener 50 forks: el lote es de un nodo.

### Actualización rodante

Para actualizar las web sin cortar el servicio, `deploy.yml` combina `serial: 1` con `delegate_to`: por cada web,
marca ese servidor como `down` en el balanceador, despliega y verifica, y lo devuelve. Mientras tanto, la otra web
atiende todo el tráfico de `prod-lb1`.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [El orden del portal](00-orden-del-portal.md) | Demostración: base de datos, web y balanceador coordinados en un playbook de varios plays |
| 01 | [Lab — Dependencias](01-lab-dependencias.md) | Arrancas el portal en orden y esperas a cada servicio con wait_for |
| 02 | [Lab — Secuencial y paralelo](02-lab-secuencial-y-paralelo.md) | Comparas serial, strategy free y async sobre los mismos nodos |
| 03 | [Lab — Orquestar varios nodos](03-lab-orquestar-nodos.md) | Sacas cada web del balanceador, la actualizas y la devuelves |

→ Empieza por **[00 — El orden del portal](00-orden-del-portal.md)**.
<!-- /gen:paginas -->
