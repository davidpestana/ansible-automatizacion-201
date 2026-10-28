# Un proyecto de equipo

[← Página anterior](README.md) · [Siguiente página →](01-lab-makefile.md)

En Tienda Norte el portal de pedidos ya no lo mantiene una persona con su runbook: lo mantiene un equipo con un
proyecto Ansible compartido. Cuando cinco personas lanzan el mismo `site.yml` con opciones distintas, el
resultado deja de ser repetible aunque el código sea el mismo. Esta página explica cómo se organiza `proyecto/`
para que todos ejecuten igual, dónde vive cada entorno y por qué camino llega un cambio de dev a prod.

## Estandarizar las ejecuciones

Un mismo despliegue de prod, lanzado por tres personas del equipo:

| Quién | Comando | Qué pasa |
|-------|---------|----------|
| Persona A | `ansible-playbook -i inventories/prod/hosts.yml site.yml` | Aplica prod sin pasar el lint ni simular |
| Persona B | `ansible-playbook site.yml` | Sin `-i`: aplica el inventario por defecto de `ansible.cfg`, que es **dev** |
| Persona C | `ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.2` | Versión mal escrita: la carpeta `app/releases/1.2` no existe |

Ninguno ha hecho nada «mal» según Ansible. El problema es que no hay **un punto de entrada**: cada uno decide el
inventario, las opciones y las comprobaciones previas. La solución es que todas las ejecuciones pasen por el mismo
sitio, versionado con el proyecto:

```bash
# Terminal del Codespace, en proyecto/
make check ENTORNO=prod
make deploy ENTORNO=prod VERSION=1.1.0 CONFIRMAR=si
```

| Propiedad | Cómo la consigue el `Makefile` |
|-----------|--------------------------------|
| Mismas opciones para todos | Cada objetivo (`check`, `site`, `deploy`) lleva escrito su `ansible-playbook` completo |
| El entorno es un parámetro, no un fichero que recordar | `ENTORNO=prod` se traduce en `-i inventories/prod/hosts.yml` |
| Comprobaciones obligatorias | `deploy` depende de `validar` (lint + sintaxis) y de `check` |
| Prod pide confirmación | Sin `CONFIRMAR=si`, el objetivo `confirmar` corta la ejecución |
| Se revisa como el código | El `Makefile` está en `proyecto/` y entra en los pull requests |

> [!NOTE]
> `make` no sustituye a Ansible ni añade lógica de despliegue: solo fija **cómo** se llama a `ansible-playbook`.
> Otros equipos usan un script `run.sh`, `just` o `task`; la idea es la misma. En los módulos siguientes, AWX y
> GitHub Actions lanzan esos mismos objetivos.

## Organización del repositorio

El proyecto del portal, tal como queda al terminar este módulo:

```text
proyecto/
├── ansible.cfg              # opciones comunes (usuario, clave, roles_path, ssh_args)
├── Makefile                 # punto de entrada: make ayuda, check, deploy…
├── .ansible-lint            # reglas de calidad (perfil production)
├── site.yml                 # db.yml + web.yml + lb.yml, en ese orden
├── db.yml  web.yml  lb.yml
├── deploy.yml               # despliegue por tandas con vuelta atrás
├── inventories/
│   ├── dev/   hosts.yml  group_vars/all.yml
│   ├── pre/   hosts.yml  group_vars/all.yml
│   └── prod/  hosts.yml  group_vars/all.yml  host_vars/prod-web2.yml
├── roles/
│   └── portal/  portal_lb/  portal_db/
└── app/releases/            # 1.0.0, 1.1.0, 1.2.0
```

| Pieza | Cambia cuando… | Quién la revisa |
|-------|----------------|-----------------|
| `roles/` y playbooks | Cambia **cómo** se instala o despliega el portal | Todo el equipo: afecta a los tres entornos |
| `inventories/<entorno>/` | Cambia **qué** hay en un entorno (versión, nodos, color) | Sobre todo quien opera ese entorno |
| `Makefile`, `.ansible-lint` | Cambia la forma de trabajar del equipo | Todo el equipo |
| `app/releases/` | Sale una versión nueva del portal | Desarrollo y operaciones |

## Entornos dev, pre y prod

Los tres entornos comparten roles y playbooks; solo cambian los datos:

| | dev | pre | prod |
|-|-----|-----|------|
| Inventario | `inventories/dev/hosts.yml` | `inventories/pre/hosts.yml` | `inventories/prod/hosts.yml` |
| Nodos | `dev-web1` | `pre-web1` | `prod-lb1`, `prod-web1`, `prod-web2`, `prod-db1` |
| `portal_version` | `1.1.0` | `1.0.0` | `1.0.0` |
| `portal_color` | `#2563eb` | `#d97706` | `#15803d` |
| Confirmación en `make` | No | No | `CONFIRMAR=si` |

> [!WARNING]
> Una rama por entorno (`dev`, `pre`, `prod`) parece ordenado, pero obliga a copiar los cambios de rama en rama
> y acaba con tres versiones del código que divergen. En este curso hay **una rama `main`** y tres carpetas de
> inventario: lo que difiere entre entornos está en los datos, no en el código.

### Qué va en Git y qué no

| Va en Git | No va en Git |
|-----------|--------------|
| Todo `proyecto/`: `ansible.cfg`, `Makefile`, `.ansible-lint`, playbooks, roles, inventarios, `group_vars`, `host_vars` | La clave SSH del curso (`~/.ssh/curso-ansible/`) |
| Las releases del portal (`app/releases/`) | Contraseñas en claro: en un proyecto real se cifran con Ansible Vault o se leen de un gestor de secretos |
| | Cachés (`.ansible/`) y copias locales (`proyecto.anterior/`), ya en `.gitignore` |

## El flujo de un cambio, de dev a prod

Ejemplo: el equipo quiere subir a 4096 las conexiones de nginx en `prod-web2`.

| Paso | Dónde | Comando o acción |
|------|-------|------------------|
| 1. Rama | Codespace | `git switch -c cambio/web2-conexiones` |
| 2. Cambio | `inventories/prod/host_vars/prod-web2.yml` | `portal_worker_connections: 4096` |
| 3. Validar | Codespace | `make validar ENTORNO=prod` (lint + sintaxis) |
| 4. Simular | Codespace | `make check ENTORNO=prod`: el `--diff` enseña la línea de `nginx.conf` que cambiará |
| 5. Pull request | GitHub | `gh pr create`: el cambio, el motivo y la salida del check |
| 6. Revisión | GitHub | Otra persona lee el diff y aprueba o pide cambios |
| 7. Merge | GitHub | El cambio entra en `main` con el número del PR |
| 8. Aplicar | Codespace, desde `main` | `make site ENTORNO=prod CONFIRMAR=si` |

Un cambio de código (un rol) sigue el mismo camino, pero se aplica primero en dev y en pre
(`make site ENTORNO=dev`, `make site ENTORNO=pre`) antes de llegar a prod.

> [!NOTE]
> La trazabilidad sale sola de este flujo: `git log` dice quién cambió `prod-web2.yml` y cuándo, el mensaje del
> commit dice por qué y el pull request guarda la revisión. En el runbook manual nada de eso quedaba escrito.

En los laboratorios de este módulo se construye cada pieza: el [Makefile](01-lab-makefile.md),
[ansible-lint](02-lab-ansible-lint.md), la [validación previa](03-lab-validacion-previa.md) y el
[cambio con pull request](04-lab-cambios-con-pr.md).
