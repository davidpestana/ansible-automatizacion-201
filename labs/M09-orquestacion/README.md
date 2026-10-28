# M09 — Orquestación

[← Página anterior](../M08-operaciones-dia-2/03-lab-troubleshooting.md) · [Siguiente página →](00-coordinacion-entre-servicios.md)

Orquestar es coordinar varios servicios que dependen unos de otros y que viven en nodos distintos: una
aplicación necesita su base de datos, un balanceador necesita la aplicación. Configurar cada pieza no basta;
hay que hacerlo en el orden correcto, comprobar que cada dependencia está lista antes de pasar a la siguiente pieza y decidir qué se
hace en paralelo y qué de uno en uno. Este módulo cubre la coordinación entre servicios, las dependencias, la
ejecución secuencial y paralela, y la orquestación de varios nodos durante una actualización sin corte de
servicio.

## Qué aprenderás

- Encadenar base de datos, aplicación y balanceador en un playbook principal con `import_playbook` y explicar qué
  se rompe si el orden cambia.
- Hacer explícita una dependencia: que la aplicación espere a que la base de datos acepte conexiones con
  `ansible.builtin.wait_for` antes de configurarse.
- Leer desde un play lo que otro play ha descubierto (`hostvars`, `groups['dbservers'][0]`), ejecutar una tarea una
  sola vez con `run_once` y lanzarla en otro nodo con `delegate_to`.
- Elegir el ritmo de una ejecución: `forks`, `serial` (fijo o por lotes), `strategy: free` frente a `linear`, y
  tareas largas en segundo plano con `async`, `poll` y `ansible.builtin.async_status`.
- Actualizar los servidores de aplicación uno a uno, sacándolos del balanceador desde el propio playbook, sin que el
  servicio deje de responder.

## Teoría

### Tres servicios, un orden

| Servicio | Depende de | Si arranca antes de tiempo |
|----------|------------|-----------------------------|
| Base de datos | nada | — |
| Aplicación (servidores web) | la base de datos acepta conexiones | La aplicación arranca, pero sus peticiones a la base de datos fallan |
| Balanceador | al menos un servidor de aplicación responde | `502 Bad Gateway` |

Ansible ejecuta los plays de un playbook **en el orden en que están escritos**, y no empieza un play hasta que
termina el anterior. Por eso el orden entre servicios se expresa así:

```yaml
# site.yml
- name: Base de datos
  ansible.builtin.import_playbook: db.yml
- name: Aplicación
  ansible.builtin.import_playbook: web.yml
- name: Balanceador
  ansible.builtin.import_playbook: lb.yml
```

> [!NOTE]
> **Orden ≠ disponibilidad.** Que el play de la base de datos termine bien quiere decir que el servicio está
> instalado y arrancado, no que ya acepte conexiones desde la aplicación. Para eso está
> `ansible.builtin.wait_for`: convierte la dependencia en una comprobación que falla con un mensaje claro si no se
> cumple.

### Dependencias: orden de plays frente a `meta/main.yml`

| Mecanismo | Dónde se escribe | Qué hace | Cuándo usarlo |
|-----------|------------------|----------|---------------|
| Orden de plays | El playbook principal | Cada servicio se configura en **sus** nodos, uno detrás de otro | Servicios en nodos distintos: db → aplicación → balanceador |
| `dependencies` en `meta/main.yml` | El rol | Ejecuta el rol dependiente **en los mismos nodos**, antes que el propio rol | Un rol que necesita otro en el mismo servidor (p. ej. un rol común de paquetes) |
| `ansible.builtin.wait_for` | Una tarea | Espera a que un puerto o un fichero estén listos | Comprobar que el servicio del que dependes responde |

> [!WARNING]
> Poner el rol de base de datos como dependencia del rol de la aplicación no hace que esta espere a la base de
> datos: instala la base de datos **en los servidores de aplicación**. Las dependencias entre nodos se resuelven
> con el orden de plays.

### Trabajar con otros nodos desde un play

| Herramienta | Para qué |
|-------------|----------|
| `groups['dbservers'][0]` | El nombre de la base de datos según el inventario, sin escribirlo a mano |
| `hostvars['db1']` | Variables, facts y registros de otro nodo, también de un play anterior |
| `run_once: true` | Una tarea que se hace una vez por ejecución (un aviso, una migración), no una por nodo |
| `delegate_to: lb1` | La tarea se ejecuta en el balanceador, pero con las variables del nodo que la lanza |

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

Para actualizar los servidores de aplicación sin cortar el servicio se combina `serial: 1` con `delegate_to`: por
cada nodo, se marca como fuera de servicio en el balanceador, se despliega y verifica, y se devuelve. Mientras
tanto, los demás atienden todo el tráfico.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Coordinación entre servicios](00-coordinacion-entre-servicios.md) | Demostración: base de datos, web y balanceador coordinados en un playbook de varios plays |
| 01 | [Lab — Dependencias](01-lab-dependencias.md) | Arrancas el portal en orden y esperas a cada servicio con wait_for |
| 02 | [Lab — Secuencial y paralelo](02-lab-secuencial-y-paralelo.md) | Comparas serial, strategy free y async sobre los mismos nodos |
| 03 | [Lab — Orquestar varios nodos](03-lab-orquestar-nodos.md) | Sacas cada web del balanceador, la actualizas y la devuelves |

→ Empieza por **[00 — Coordinación entre servicios](00-coordinacion-entre-servicios.md)**.
<!-- /gen:paginas -->
