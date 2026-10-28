# AWX y Ansible Automation Platform

[← Página anterior](README.md) · [Siguiente página →](01-demo-awx.md)

En Tienda Norte, el despliegue del portal ya está automatizado: `deploy.yml` actualiza `prod-web1` y
`prod-web2` uno a uno, los saca del balanceador y vuelve atrás si la release no responde. Lo que no está
resuelto es el gobierno de esa automatización: hoy despliega quien tiene la clave `curso_ansible` en su
Codespace, el inventario de prod es el que cada uno tenga en su copia y el único registro es la pantalla
de quien lo lanzó. Esta página explica qué añade un controlador central como AWX y qué aporta su versión
enterprise, Red Hat Ansible Automation Platform.

## Qué resuelve un controlador central

Un controlador es un servicio web que guarda los playbooks, los inventarios y las credenciales, y lanza
`ansible-playbook` en nombre de las personas. Nadie necesita la clave SSH ni un nodo de control propio:
basta con un usuario en el controlador y permiso sobre lo que va a ejecutar.

| Capacidad | Qué significa | En Tienda Norte |
|-----------|---------------|-----------------|
| Inventarios centralizados | Un inventario por entorno, sincronizado desde Git o desde una fuente dinámica (nube, VMware, CMDB) | «Portal prod» con `prod-lb1`, `prod-web1`, `prod-web2` y `prod-db1`, igual para todos |
| Credenciales guardadas | Claves SSH, contraseñas de sudo, tokens de nube o de Git cifrados en la base de datos; se usan, no se ven | La clave del usuario `ansible` deja de estar en cada Codespace |
| Plantillas de job | Playbook + inventario + credencial + variables, empaquetados con un nombre | «Desplegar portal» lanza `proyecto/deploy.yml` contra prod |
| Encuestas (surveys) | Preguntas al lanzar una plantilla, que se convierten en variables | Elegir `portal_version` de una lista en lugar de escribir `-e` |
| RBAC | Permisos por organización, equipo y usuario sobre cada objeto (ver, usar, lanzar, administrar) | El equipo de guardia puede lanzar el despliegue, pero no cambiar la plantilla ni leer la clave |
| Programación | Ejecuciones periódicas sin cron en ningún servidor | Un `site.yml` en modo check cada noche para detectar deriva en prod |
| Auditoría | Cada job queda guardado con su salida, sus eventos por host, quién lo lanzó y con qué variables; cada cambio de configuración, en un flujo de actividad | Responder «¿quién desplegó la 1.2.0 y qué pasó en `prod-web1`?» |
| API REST | Todo lo que hace la interfaz se puede hacer por API | Un pipeline o una herramienta de tickets lanza la plantilla sin abrir la web |
| Notificaciones y workflows | Avisos al terminar un job y cadenas de plantillas con ramas de éxito o fallo | Avisar al canal de operaciones si el despliegue acaba en rollback |

> [!NOTE]
> El controlador no instala nada en los nodos. Sigue siendo Ansible sin agentes: SSH con un usuario y una
> clave. Lo que cambia es dónde vive esa clave y quién puede pedir que se use.

### Cómo ejecuta AWX un playbook

| Paso | Qué hace AWX | Equivalente en el terminal |
|------|--------------|----------------------------|
| Sincronizar el proyecto | Clona o actualiza el repositorio Git en la rama indicada | `git pull` |
| Sincronizar el inventario | Ejecuta `ansible-inventory` sobre el fichero o la fuente y guarda hosts, grupos y variables | `ansible-inventory -i inventories/prod/hosts.yml --list` |
| Lanzar el job | Arranca un *execution environment* (contenedor con ansible-core y colecciones) y ejecuta el playbook con la credencial inyectada | `ansible-playbook -i … deploy.yml -e portal_version=…` |
| Guardar el resultado | Almacena la salida completa y cada evento (tarea × host) en su base de datos | Lo que se ve en pantalla, y se pierde al cerrarla |

> [!NOTE]
> AWX ejecuta el playbook desde la raíz del repositorio, no desde `proyecto/`. Por eso no lee
> `proyecto/ansible.cfg`: usuario remoto, clave y opciones de SSH llegan por la credencial y por la
> configuración de AWX. Lo que sí funciona igual es todo lo que es relativo al playbook: los roles en
> `proyecto/roles/`, los `group_vars` junto al inventario y `{{ playbook_dir }}/app/releases/`.

## AWX y Red Hat Ansible Automation Platform

AWX es el proyecto de código abierto (upstream) del que sale el *automation controller* de Red Hat Ansible
Automation Platform (AAP). Comparten origen y conceptos: lo que se ve en la demo de AWX vale para AAP.
La diferencia está en el producto que hay alrededor.

| Aspecto | AWX | Red Hat Ansible Automation Platform |
|---------|-----|-------------------------------------|
| Licencia y coste | Libre (Apache 2.0), sin suscripción | Suscripción de Red Hat, según los nodos gestionados |
| Soporte | Comunidad (foros, GitHub); sin soporte comercial | Soporte de Red Hat, parches de seguridad y erratas |
| Ciclo de vida | Versiones frecuentes, sin versiones de largo soporte ni ruta de actualización garantizada | Versiones con ciclo de vida publicado y actualización soportada |
| Instalación | AWX Operator sobre Kubernetes | Instalador para RHEL (también en contenedores) u Operator en OpenShift |
| Componentes | El controlador | Controlador, hub, Event-Driven Ansible, herramientas de desarrollo y contenido certificado |
| Pensado para | Laboratorio, aprendizaje, equipos que asumen operarlo | Producción con requisitos de soporte, auditoría y cumplimiento |

> [!WARNING]
> AWX es un proyecto de desarrollo, no un producto: cambia rápido y no garantiza actualizaciones limpias
> entre versiones. La demo usa AWX 24.6.1 con AWX Operator 2.19.1, versiones fijadas en
> `infra/awx/kustomization.yaml`. Para prod con soporte, la opción de Red Hat es AAP.

### Las piezas de AAP

| Pieza | Para qué sirve | En Tienda Norte |
|-------|----------------|-----------------|
| Automation controller | El controlador: inventarios, credenciales, plantillas, RBAC, programación, auditoría, API (lo que en upstream es AWX) | Donde operaciones lanza «Desplegar portal» |
| Private automation hub | Repositorio interno de colecciones y de execution environments aprobados | Publicar las colecciones que usa el portal (`community.postgresql`) en una versión validada, sin salir a Internet |
| Contenido certificado y validado | Colecciones firmadas y soportadas por Red Hat y sus socios | Usar colecciones con soporte en lugar de versiones sueltas de Galaxy |
| Event-Driven Ansible | Reglas que lanzan automatización al llegar un evento (alerta de monitorización, webhook, mensaje) | Si la monitorización avisa de que `prod-web2` no responde, lanzar una plantilla que lo saque del balanceador |
| Execution environments | Imágenes de contenedor con ansible-core, colecciones y dependencias de Python; se construyen con `ansible-builder` y se prueban con `ansible-navigator` | La misma imagen en el puesto de quien desarrolla y en el controlador |
| Automation mesh | Nodos de ejecución repartidos por redes o sedes, conectados al controlador | Un nodo de ejecución dentro de la red de una tienda física, sin abrir SSH desde fuera |

> [!NOTE]
> Los *execution environments* sustituyen a los `virtualenv` de las versiones antiguas de Tower: el job
> corre dentro de una imagen, no en el Python del servidor. Si un playbook necesita una colección que la
> imagen no trae, se añade al EE o se declara en un `collections/requirements.yml` del proyecto.

## Enfoque enterprise: quién ejecuta qué en prod

Con un controlador, la pregunta deja de ser «¿quién tiene la clave?» y pasa a ser «¿quién tiene qué
permiso sobre qué plantilla?». Un reparto posible para el portal:

| Perfil | Permisos en el controlador | Qué puede hacer |
|--------|----------------------------|-----------------|
| Administración de la plataforma | Administrador del sistema | Instalar, actualizar, gestionar organizaciones e integraciones |
| Responsable del portal | Admin de la organización Tienda Norte | Crear proyectos, inventarios, credenciales y plantillas |
| Desarrollo | Execute sobre la plantilla de pre; Read sobre la de prod | Desplegar en pre cuando lo necesite; ver los jobs de prod, no lanzarlos |
| Operación de guardia | Execute sobre «Desplegar portal» en prod | Lanzar con la versión que elija en la encuesta; no editar la plantilla ni ver la clave |
| Auditoría / seguridad | Auditor | Ver todo (jobs, configuración, actividad) sin cambiar nada |

| Práctica | Por qué |
|----------|---------|
| Una credencial por entorno | Una clave de pre filtrada no da acceso a prod |
| Plantillas con encuesta y opciones cerradas | Quien lanza elige entre versiones válidas, no escribe variables libres |
| Proyecto ligado a la rama `main` | En prod solo se ejecuta lo que ha pasado por revisión (el flujo de PR del M10) |
| Permisos a equipos, no a personas | Entrar o salir del equipo de guardia cambia los permisos de golpe |
| Autenticación corporativa (LDAP, SAML, OIDC) | Las altas y bajas siguen al directorio de la empresa |
| Programar la comprobación en modo check | La deriva en prod se detecta sin esperar al siguiente despliegue |

> [!TIP]
> Un controlador no hace seguro un playbook inseguro. `serial: 1`, `max_fail_percentage: 0` y el rollback
> de `deploy.yml` siguen siendo los que evitan que una release rota llegue a los dos nodos web; el
> controlador decide quién puede pulsar el botón y deja constancia de que lo pulsó.

La [demostración de AWX](01-demo-awx.md) recorre este reparto con el portal: proyecto, inventario,
credencial, plantilla, job y permisos de un equipo de operación.
