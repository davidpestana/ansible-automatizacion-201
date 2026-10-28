# Estandarizar y organizar un proyecto

[← Página anterior](README.md) · [Siguiente página →](01-lab-makefile.md)

Un proyecto Ansible compartido por un equipo solo da resultados repetibles si todos lo ejecutan igual, si cada
entorno tiene un sitio claro y si los cambios siguen un camino conocido hasta producción. Esta página explica
cómo se estandarizan las ejecuciones, cómo se organizan el repositorio y los entornos, y cómo viaja un cambio de
desarrollo a producción con trazabilidad.

## Estandarizar las ejecuciones

Un mismo despliegue a producción, lanzado por tres personas de un equipo:

| Quién | Comando | Qué pasa |
|-------|---------|----------|
| Persona A | `ansible-playbook -i inventories/prod/hosts.yml site.yml` | Aplica producción sin pasar el lint ni simular |
| Persona B | `ansible-playbook site.yml` | Sin `-i`: aplica el inventario por defecto de `ansible.cfg`, que quizá es el de desarrollo |
| Persona C | `ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e app_version=1.2` | Versión mal escrita: esa release no existe |

Ninguno ha hecho nada «mal» según Ansible. El problema es que no hay **un punto de entrada**: cada uno decide el
inventario, las opciones y las comprobaciones previas. La solución es que todas las ejecuciones pasen por el mismo
sitio, versionado con el proyecto. Un `Makefile` es una forma sencilla de hacerlo:

```bash
make check ENTORNO=prod
make deploy ENTORNO=prod VERSION=1.1.0 CONFIRMAR=si
```

| Propiedad | Cómo la consigue el punto de entrada |
|-----------|--------------------------------------|
| Mismas opciones para todos | Cada objetivo (`check`, `site`, `deploy`) lleva escrito su `ansible-playbook` completo |
| El entorno es un parámetro, no un fichero que recordar | `ENTORNO=prod` se traduce en `-i inventories/prod/hosts.yml` |
| Comprobaciones obligatorias | `deploy` depende de `validar` (lint + sintaxis) y de `check` |
| Producción pide confirmación | Sin `CONFIRMAR=si`, la ejecución se corta |
| Se revisa como el código | El `Makefile` vive en el repositorio y entra en los pull requests |

> [!NOTE]
> `make` no sustituye a Ansible ni añade lógica de despliegue: solo fija **cómo** se llama a `ansible-playbook`.
> Otros equipos usan un script `run.sh`, `just` o `task`; la idea es la misma. Un controlador (AWX) o un pipeline
> de CI/CD pueden lanzar después esos mismos objetivos.

## Organización del repositorio

Una estructura habitual para un proyecto con varios entornos:

```text
proyecto/
├── ansible.cfg              # opciones comunes (usuario, clave, roles_path, ssh_args)
├── Makefile                 # punto de entrada: make ayuda, check, deploy…
├── .ansible-lint            # reglas de calidad
├── site.yml                 # playbook principal: importa los demás en orden
├── db.yml  web.yml  lb.yml
├── deploy.yml               # despliegue de versiones
├── inventories/
│   ├── dev/   hosts.yml  group_vars/  host_vars/
│   ├── pre/   hosts.yml  group_vars/  host_vars/
│   └── prod/  hosts.yml  group_vars/  host_vars/
└── roles/
    └── webserver/  loadbalancer/  database/
```

| Pieza | Cambia cuando… | Quién la revisa |
|-------|----------------|-----------------|
| `roles/` y playbooks | Cambia **cómo** se instala o despliega algo | Todo el equipo: afecta a todos los entornos |
| `inventories/<entorno>/` | Cambia **qué** hay en un entorno (versión, nodos, ajustes) | Sobre todo quien opera ese entorno |
| `Makefile`, `.ansible-lint` | Cambia la forma de trabajar del equipo | Todo el equipo |

## Entornos: carpetas, no ramas

Los entornos comparten roles y playbooks; solo cambian los datos:

| | dev | pre | prod |
|-|-----|-----|------|
| Inventario | `inventories/dev/hosts.yml` | `inventories/pre/hosts.yml` | `inventories/prod/hosts.yml` |
| Nodos | Uno pequeño | Una copia reducida de producción | Todos los de producción |
| Versión desplegada | La última en pruebas | La candidata | La estable |
| Confirmación al ejecutar | No | No | Sí |

> [!WARNING]
> Una rama por entorno (`dev`, `pre`, `prod`) parece ordenado, pero obliga a copiar los cambios de rama en rama
> y acaba con varias versiones del código que divergen. Lo habitual es **una rama `main`** y una carpeta de
> inventario por entorno: lo que difiere entre entornos está en los datos, no en el código.

### Qué va en Git y qué no

| Va en Git | No va en Git |
|-----------|--------------|
| `ansible.cfg`, `Makefile`, `.ansible-lint`, playbooks, roles, inventarios, `group_vars`, `host_vars` | Claves SSH privadas |
| Secretos **cifrados** con Ansible Vault | Contraseñas en claro |
| | Cachés (`.ansible/`) y ficheros locales, en `.gitignore` |

## El flujo de un cambio, de dev a prod

Ejemplo: subir el límite de conexiones de nginx en un servidor de producción.

| Paso | Dónde | Comando o acción |
|------|-------|------------------|
| 1. Rama | Equipo local | `git switch -c cambio/web2-conexiones` |
| 2. Cambio | `inventories/prod/host_vars/web2.yml` | `webserver_worker_connections: 4096` |
| 3. Validar | Equipo local o CI | `make validar ENTORNO=prod` (lint + sintaxis) |
| 4. Simular | Equipo local o CI | `make check ENTORNO=prod`: el `--diff` enseña la línea de configuración que cambiará |
| 5. Pull request | Plataforma Git | El cambio, el motivo y la salida del check |
| 6. Revisión | Plataforma Git | Otra persona lee el diff y aprueba o pide cambios |
| 7. Merge | Plataforma Git | El cambio entra en `main` con el número del PR |
| 8. Aplicar | Desde `main` | `make site ENTORNO=prod CONFIRMAR=si` |

Un cambio de código (un rol) sigue el mismo camino, pero se aplica primero en dev y en pre antes de llegar a prod.

> [!NOTE]
> La trazabilidad sale sola de este flujo: `git log` dice quién cambió cada fichero y cuándo, el mensaje del
> commit dice por qué y el pull request guarda la revisión. En un procedimiento manual nada de eso queda escrito.

## En los laboratorios

Sobre el proyecto del caso se construye cada pieza: el [Makefile](01-lab-makefile.md),
[ansible-lint](02-lab-ansible-lint.md), la [validación previa](03-lab-validacion-previa.md) y el
[cambio con pull request](04-lab-cambios-con-pr.md).
