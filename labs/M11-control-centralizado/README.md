# M11 — Control centralizado de ejecuciones

[← Página anterior](../M10-gobernanza/04-lab-cambios-con-pr.md) · [Siguiente página →](00-awx-y-aap.md)

Lanzar Ansible desde un terminal funciona para una persona o un equipo pequeño, pero en producción deja preguntas
sin respuesta: quién puede ejecutar qué, con qué credenciales, qué se lanzó ayer y por qué falló. Un
**controlador central** responde a esas preguntas: guarda inventarios y credenciales, define quién puede lanzar
cada automatización, la programa, registra cada ejecución y la expone por API. Este módulo presenta AWX (el
proyecto de código abierto) y Red Hat Ansible Automation Platform (la versión con soporte), y la alternativa de
ejecutar Ansible desde un pipeline de CI/CD.

## Qué aprenderás

- Explicar qué añade un controlador central a los playbooks: inventario único, credenciales guardadas, permisos por
  equipo, plantillas, programación, auditoría y API.
- Distinguir AWX de Red Hat Ansible Automation Platform y saber qué piezas trae la versión enterprise.
- Reconocer en AWX las piezas de un proyecto Ansible: repositorio, inventario, clave SSH y playbook, convertidos
  en proyecto, inventario, credencial y plantilla.
- Leer la salida de un job y sus eventos por host, y saber dónde mirar quién lanzó qué.
- Decidir entre un controlador (AWX/AAP) y un pipeline de GitHub Actions o GitLab CI según la necesidad.

## Teoría

Los playbooks no cambian: son los mismos se lancen desde el terminal, desde AWX o desde un pipeline. Cambia
**quién** los lanza, **con qué** permisos y credenciales, y **dónde** queda el registro.

| Pregunta en producción | Desde el terminal | Desde un controlador (AWX/AAP) | Desde CI/CD |
|------------------------|-------------------|--------------------------------|-------------|
| ¿Quién puede ejecutar? | Quien tenga la clave SSH | Usuarios y equipos con permiso sobre la plantilla | Quien pueda lanzar el workflow o aprobar el entorno |
| ¿Dónde está la clave? | En `~/.ssh/` de cada persona | Cifrada en el controlador; nadie la ve | En los secretos del repositorio o del proyecto |
| ¿Qué hosts hay? | El inventario de la copia local | Un inventario sincronizado, visible para todos | El inventario del commit que se ejecuta |
| ¿Qué pasó ayer? | Lo que recuerde quien lo lanzó | Job con salida, eventos por host, usuario y variables | Log del pipeline, ligado a un commit |

Vocabulario de AWX:

| Objeto de AWX | Qué es |
|---------------|--------|
| Organization | Agrupa usuarios, equipos y recursos de una organización o departamento |
| Project | Un repositorio Git con playbooks; AWX lo clona y lo sincroniza |
| Inventory | Hosts y grupos, escritos a mano o importados de un fichero del proyecto o de una fuente dinámica |
| Credential | Secreto guardado cifrado: clave SSH (*Machine*), token de Git, credenciales de nube… |
| Job Template | Playbook + inventario + credencial + variables: lo que se lanza con un botón |
| Job | Una ejecución de una plantilla, con su salida y su resultado por host |
| Team / User | Quién puede ver, lanzar o administrar cada objeto |

> [!NOTE]
> AWX no sustituye a Ansible: dentro de cada job ejecuta `ansible-playbook` en un *execution environment*
> (una imagen de contenedor con ansible-core y colecciones). Lo que se sabe de playbooks, roles e inventarios
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
