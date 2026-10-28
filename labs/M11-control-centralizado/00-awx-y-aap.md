# AWX y Ansible Automation Platform

[← Página anterior](README.md) · [Siguiente página →](01-demo-awx.md)

Automatizar una tarea con un playbook no resuelve quién puede ejecutarla, con qué credenciales, contra qué
inventario ni dónde queda constancia de lo que pasó. Un controlador central resuelve ese gobierno de la
automatización. Esta página explica qué añade un controlador como AWX, cómo ejecuta los playbooks y qué aporta
su versión enterprise, Red Hat Ansible Automation Platform.

## Qué resuelve un controlador central

Un controlador es un servicio web que guarda los playbooks, los inventarios y las credenciales, y lanza
`ansible-playbook` en nombre de las personas. Nadie necesita la clave SSH ni un nodo de control propio:
basta con un usuario en el controlador y permiso sobre lo que va a ejecutar.

| Capacidad | Qué significa | Ejemplo |
|-----------|---------------|---------|
| Inventarios centralizados | Un inventario por entorno, sincronizado desde Git o desde una fuente dinámica (nube, VMware, CMDB) | El inventario de producción es el mismo para todos, no el de cada copia local |
| Credenciales guardadas | Claves SSH, contraseñas de sudo, tokens de nube o de Git cifrados en la base de datos; se usan, no se ven | La clave de producción deja de estar en los portátiles |
| Plantillas de job | Playbook + inventario + credencial + variables, empaquetados con un nombre | «Desplegar aplicación» lanza `deploy.yml` contra producción |
| Encuestas (surveys) | Preguntas al lanzar una plantilla, que se convierten en variables | Elegir la versión de una lista en lugar de escribir `-e` |
| RBAC | Permisos por organización, equipo y usuario sobre cada objeto (ver, usar, lanzar, administrar) | El equipo de guardia puede lanzar el despliegue, pero no cambiar la plantilla ni leer la clave |
| Programación | Ejecuciones periódicas sin cron en ningún servidor | Un `site.yml` en modo check cada noche para detectar deriva |
| Auditoría | Cada job queda guardado con su salida, sus eventos por host, quién lo lanzó y con qué variables; cada cambio de configuración, en un flujo de actividad | Responder «¿quién desplegó la versión 1.2.0 y qué pasó en cada servidor?» |
| API REST | Todo lo que hace la interfaz se puede hacer por API | Un pipeline o una herramienta de tickets lanza la plantilla sin abrir la web |
| Notificaciones y workflows | Avisos al terminar un job y cadenas de plantillas con ramas de éxito o fallo | Avisar al canal de operaciones si un despliegue acaba en vuelta atrás |

> [!NOTE]
> El controlador no instala nada en los nodos. Sigue siendo Ansible sin agentes: SSH con un usuario y una
> clave. Lo que cambia es dónde vive esa clave y quién puede pedir que se use.

### Cómo ejecuta AWX un playbook

| Paso | Qué hace AWX | Equivalente en el terminal |
|------|--------------|----------------------------|
| Sincronizar el proyecto | Clona o actualiza el repositorio Git en la rama indicada | `git pull` |
| Sincronizar el inventario | Ejecuta `ansible-inventory` sobre el fichero o la fuente y guarda hosts, grupos y variables | `ansible-inventory -i inventories/prod/hosts.yml --list` |
| Lanzar el job | Arranca un *execution environment* (contenedor con ansible-core y colecciones) y ejecuta el playbook con la credencial inyectada | `ansible-playbook -i … deploy.yml -e version=…` |
| Guardar el resultado | Almacena la salida completa y cada evento (tarea × host) en su base de datos | Lo que se ve en pantalla, y se pierde al cerrarla |

> [!NOTE]
> AWX ejecuta el playbook desde la raíz del repositorio clonado y aporta su propia configuración: usuario
> remoto, clave y opciones de SSH llegan por la credencial y por los ajustes de AWX, no por un `ansible.cfg`
> que esté en una subcarpeta. Lo que sí funciona igual es todo lo relativo al playbook: los roles junto a él,
> los `group_vars` junto al inventario y las rutas con `{{ playbook_dir }}`.

## AWX y Red Hat Ansible Automation Platform

AWX es el proyecto de código abierto (upstream) del que sale el *automation controller* de Red Hat Ansible
Automation Platform (AAP). Comparten origen y conceptos: lo que se aprende con AWX vale para AAP. La diferencia
está en el producto que hay alrededor.

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
> entre versiones. Conviene fijar la versión de AWX y la del AWX Operator. Para producción con soporte, la
> opción de Red Hat es AAP.

### Las piezas de AAP

| Pieza | Para qué sirve | Ejemplo |
|-------|----------------|---------|
| Automation controller | El controlador: inventarios, credenciales, plantillas, RBAC, programación, auditoría, API (lo que en upstream es AWX) | Donde operaciones lanza las plantillas |
| Private automation hub | Repositorio interno de colecciones y de execution environments aprobados | Publicar las colecciones que usa la organización en versiones validadas, sin salir a Internet |
| Contenido certificado y validado | Colecciones firmadas y soportadas por Red Hat y sus socios | Usar colecciones con soporte en lugar de versiones sueltas de Galaxy |
| Event-Driven Ansible | Reglas que lanzan automatización al llegar un evento (alerta de monitorización, webhook, mensaje) | Si la monitorización avisa de que un servidor no responde, lanzar una plantilla que lo saque del balanceador |
| Execution environments | Imágenes de contenedor con ansible-core, colecciones y dependencias de Python; se construyen con `ansible-builder` y se prueban con `ansible-navigator` | La misma imagen en el puesto de quien desarrolla y en el controlador |
| Automation mesh | Nodos de ejecución repartidos por redes o sedes, conectados al controlador | Un nodo de ejecución dentro de una red remota, sin abrir SSH desde fuera |

> [!NOTE]
> Los *execution environments* sustituyen a los `virtualenv` de las versiones antiguas de Tower: el job
> corre dentro de una imagen, no en el Python del servidor. Si un playbook necesita una colección que la
> imagen no trae, se añade al EE o se declara en un `collections/requirements.yml` del proyecto. El EE que
> AWX usa por defecto (*AWX EE (latest)*) es mínimo: trae su propia versión de ansible-core, que no tiene por qué
> coincidir con la del puesto de trabajo, y casi ninguna colección aparte de `ansible.posix`.

## Enfoque enterprise: quién ejecuta qué en producción

Con un controlador, la pregunta deja de ser «¿quién tiene la clave?» y pasa a ser «¿quién tiene qué
permiso sobre qué plantilla?». Un reparto habitual:

| Perfil | Permisos en el controlador | Qué puede hacer |
|--------|----------------------------|-----------------|
| Administración de la plataforma | Administrador del sistema | Instalar, actualizar, gestionar organizaciones e integraciones |
| Responsable del servicio | Admin de su organización | Crear proyectos, inventarios, credenciales y plantillas |
| Desarrollo | Execute sobre la plantilla de preproducción; Read sobre la de producción | Desplegar en pre cuando lo necesite; ver los jobs de producción, no lanzarlos |
| Operación de guardia | Execute sobre la plantilla de producción | Lanzar con la versión que elija en la encuesta; no editar la plantilla ni ver la clave |
| Auditoría / seguridad | Auditor | Ver todo (jobs, configuración, actividad) sin cambiar nada |

| Práctica | Por qué |
|----------|---------|
| Una credencial por entorno | Una clave de preproducción filtrada no da acceso a producción |
| Plantillas con encuesta y opciones cerradas | Quien lanza elige entre valores válidos, no escribe variables libres |
| Proyecto ligado a la rama `main` | En producción solo se ejecuta lo que ha pasado por revisión |
| Permisos a equipos, no a personas | Entrar o salir de un equipo cambia los permisos de golpe |
| Autenticación corporativa (LDAP, SAML, OIDC) | Las altas y bajas siguen al directorio de la empresa |
| Programar la comprobación en modo check | La deriva se detecta sin esperar al siguiente despliegue |

> [!TIP]
> Un controlador no hace seguro un playbook inseguro. `serial`, `max_fail_percentage` y la vuelta atrás del
> propio playbook siguen siendo lo que evita que una versión rota llegue a todos los nodos; el controlador
> decide quién puede pulsar el botón y deja constancia de que lo pulsó.

## En los laboratorios

La [demostración de AWX](01-demo-awx.md) monta este reparto sobre el caso del curso: proyecto, inventario,
credencial, plantilla con encuesta, job y permisos de un equipo de operación.
