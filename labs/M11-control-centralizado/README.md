# M11 — Control centralizado de ejecuciones

[← Página anterior](../M10-gobernanza/04-lab-cambios-con-pr.md) · [Siguiente página →](00-awx-y-aap.md)

Hasta aquí, el portal de Tienda Norte se despliega desde un terminal: quien tiene el Codespace, la clave
SSH y el `Makefile` lanza `make deploy ENTORNO=prod VERSION=1.1.0 CONFIRMAR=si`, y lo que pasó queda en
su pantalla. Funciona para un equipo pequeño, pero en prod deja preguntas sin respuesta: quién puede
desplegar, con qué clave, qué versión se lanzó el martes y por qué falló. Este módulo responde a esas
preguntas con un **controlador central**: AWX (y su versión con soporte, Red Hat Ansible Automation
Platform), y con la alternativa de lanzar Ansible desde un pipeline de CI/CD.

## Qué aprenderás

- Explicar qué añade un controlador central a los playbooks del portal: inventario único, credenciales
  guardadas, permisos por equipo, plantillas, programación, auditoría y API.
- Distinguir AWX de Red Hat Ansible Automation Platform y saber qué piezas trae la versión enterprise.
- Reconocer en AWX el mismo proyecto que ya conoces: `proyecto/deploy.yml`, el inventario de prod y la clave
  del usuario `ansible`, convertidos en proyecto, inventario, credencial y plantilla.
- Leer la salida de un job y sus eventos por host, y saber dónde mirar quién lanzó qué.
- Decidir entre AWX/AAP y un pipeline de GitHub Actions o GitLab CI según lo que necesite Tienda Norte.

## Teoría

Los playbooks no cambian: `site.yml` y `deploy.yml` son los mismos se lancen desde el terminal, desde AWX o
desde un pipeline. Cambia **quién** los lanza, **con qué** permisos y credenciales, y **dónde** queda el
registro.

| Pregunta en prod | Desde el terminal | Desde un controlador (AWX/AAP) | Desde CI/CD |
|------------------|-------------------|--------------------------------|-------------|
| ¿Quién puede desplegar? | Quien tenga la clave SSH | Usuarios y equipos con permiso sobre la plantilla | Quien pueda lanzar el workflow o aprobar el entorno |
| ¿Dónde está la clave? | En `~/.ssh/` de cada persona | Cifrada en el controlador; nadie la ve | En los secretos del repositorio o del proyecto |
| ¿Qué hosts hay en prod? | El `hosts.yml` de la copia local | Un inventario sincronizado, visible para todos | El `hosts.yml` del commit que se ejecuta |
| ¿Qué pasó el martes? | Lo que recuerde quien lo lanzó | Job con salida, eventos por host, usuario y variables | Log del pipeline, ligado a un commit |

Vocabulario de AWX que aparece en la demo:

| Objeto de AWX | Qué es en Tienda Norte |
|---------------|------------------------|
| Organization | Tienda Norte: agrupa todo lo demás |
| Project | El fork en GitHub con `proyecto/`; AWX lo clona y lo sincroniza |
| Inventory | «Portal prod», importado de `proyecto/inventories/prod/hosts.yml` |
| Credential (Machine) | Usuario `ansible` y la clave `curso_ansible`, guardados cifrados |
| Job Template | «Desplegar portal»: playbook + inventario + credencial + variables |
| Job | Una ejecución de una plantilla, con su salida y su resultado por host |
| Team / User | Quién puede ver, lanzar o administrar cada objeto |

> [!NOTE]
> AWX no sustituye a Ansible: dentro de cada job ejecuta `ansible-playbook` en un *execution environment*
> (una imagen de contenedor con ansible-core y colecciones). Lo que sabes de playbooks, roles e inventarios
> sigue valiendo tal cual.

> [!NOTE]
> CI/CD no es «AWX pero gratis». Un pipeline encaja cuando el despliegue nace de un cambio en Git; un
> controlador encaja cuando operaciones lanza, programa y audita ejecuciones contra un inventario vivo.
> Muchas organizaciones usan los dos: el pipeline valida y llama a la API del controlador para desplegar.

## Páginas

<!-- gen:paginas -->
| # | Página | Qué hay |
|---|--------|---------|
| 00 | [AWX y Ansible Automation Platform](00-awx-y-aap.md) | Qué añade un controlador central y qué aporta la versión enterprise |
| 01 | [El portal desde AWX](01-demo-awx.md) | Demostración: proyecto, inventario, credencial y plantilla del portal; job, logs, permisos y auditoría |
| 02 | [CI/CD como alternativa](02-cicd-como-alternativa.md) | GitHub Actions y GitLab CI frente a AWX: qué se gana y qué se pierde |

→ Empieza por **[00 — AWX y Ansible Automation Platform](00-awx-y-aap.md)**.
<!-- /gen:paginas -->
