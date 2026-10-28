# M10 — Gobernanza y operación de Ansible

[← Página anterior](../M09-orquestacion/03-lab-orquestar-nodos.md) · [Siguiente página →](00-un-proyecto-de-equipo.md)

Hasta aquí `proyecto/` lo ha lanzado cada uno a su manera: con su inventario, sus `-e` y sus opciones. En el
equipo de operaciones de Tienda Norte eso ya no vale: el portal tiene tres entornos, varias personas tocan el mismo
proyecto y prod no admite sorpresas. Este módulo es la **gobernanza** del proyecto: un único punto de entrada
(`Makefile`) con las mismas opciones para todos, reglas de calidad automáticas con `ansible-lint`, una validación
previa en modo check antes de tocar prod y los cambios llevados por rama, pull request y revisión en tu fork.

## Qué aprenderás

- Ejecutar el proyecto siempre igual con `make ping`, `make check`, `make deploy`… y el entorno como parámetro
  (`ENTORNO=dev|pre|prod`), con una guarda que obliga a confirmar en prod.
- Leer un informe de `ansible-lint` (regla, fichero, línea), elegir un perfil y corregir los avisos en lugar de
  silenciarlos.
- Encadenar `lint`, `syntax-check` y `--check --diff` antes de aplicar, y saber qué no puede predecir el modo check.
- Llevar un cambio del portal desde una rama hasta `main` con un pull request revisado y encontrar después quién lo
  hizo, cuándo y por qué.

## Teoría

### De «cada uno lo lanza a su manera» a un punto de entrada

| Sin estandarizar | Con `Makefile` |
|------------------|----------------|
| `ansible-playbook -i inventories/prod/hosts.yml site.yml` y cada uno añade lo que recuerda | `make site ENTORNO=prod CONFIRMAR=si` |
| Alguien olvida `-i` y aplica sobre el inventario por defecto (dev) | El inventario sale del parámetro `ENTORNO` |
| Se despliega sin pasar el lint ni simular | `make deploy` ejecuta antes `lint`, `syntax` y `check` |
| Nadie sabe qué comandos son «los buenos» | `make ayuda` los lista; el `Makefile` está en Git y se revisa |

### Qué va en Git y qué no

| En el repositorio | Fuera del repositorio |
|-------------------|------------------------|
| `proyecto/`: playbooks, roles, `inventories/<entorno>/`, `group_vars`, `host_vars`, `Makefile`, `.ansible-lint` | Claves SSH (`~/.ssh/curso-ansible/`) |
| `app/releases/` con las versiones del portal | Contraseñas en claro (en un proyecto real, Ansible Vault o el gestor de secretos) |
| `ansible.cfg` del proyecto | Cachés y copias locales (`.ansible/`, `proyecto.anterior/`) |

### Los entornos son carpetas, no ramas

Cada entorno es un inventario con sus variables: `inventories/dev/`, `inventories/pre/` e `inventories/prod/`. El
**mismo código** (roles y playbooks) se aplica a los tres; lo que cambia son los datos (versión, color, nodos). Un
cambio sube de entorno así: se prueba en dev, se aplica en pre, se revisa en un pull request y, ya en `main`, se
aplica en prod con `make`.

> [!NOTE]
> `ansible-lint`, `--syntax-check` y `--check` no son lo mismo. El primero revisa el estilo y las malas prácticas
> sin conectarse a ningún nodo; el segundo solo comprueba que el YAML se puede cargar; el tercero sí se conecta
> y simula la ejecución contra los nodos reales.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [Un proyecto de equipo](00-un-proyecto-de-equipo.md) | Repositorio, entornos dev/pre/prod y un único punto de entrada para todos |
| 01 | [Lab — Makefile](01-lab-makefile.md) | Creas make check, make deploy y make lint con el entorno como parámetro |
| 02 | [Lab — ansible-lint](02-lab-ansible-lint.md) | Lees los avisos de ansible-lint sobre el proyecto y los corriges |
| 03 | [Lab — Validación previa](03-lab-validacion-previa.md) | Encadenas lint, syntax-check y check y solo entonces aplicas |
| 04 | [Lab — Cambios con PR](04-lab-cambios-con-pr.md) | Llevas un cambio del portal por rama, pull request y revisión en tu fork |

→ Empieza por **[00 — Un proyecto de equipo](00-un-proyecto-de-equipo.md)**.
<!-- /gen:paginas -->
