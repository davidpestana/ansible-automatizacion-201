# CI/CD como alternativa

[← Página anterior](01-demo-awx.md) · [Siguiente página →](../M12-integracion-devops/README.md)

Tienda Norte ya guarda el proyecto del portal en GitHub y revisa cada cambio con pull requests (M10). Antes
de montar y operar un AWX, cabe otra pregunta: si el código ya vive en Git y cada cambio pasa por revisión,
¿no basta con que el propio sistema de CI/CD lance `ansible-playbook`? Esta página compara esa opción, con
GitHub Actions y con GitLab CI, frente a un controlador como AWX o Red Hat Ansible Automation Platform.

## Ansible dentro de un pipeline

Un pipeline que ejecuta Ansible hace lo mismo que el terminal del Codespace, pero en una máquina efímera y
disparado por un evento de Git (un push, un pull request, un merge a `main`) o por un botón manual.

| Pieza | Qué es | En Tienda Norte |
|-------|--------|-----------------|
| Runner | La máquina que ejecuta el job: alojada por GitHub/GitLab o propia (*self-hosted*) | Necesita `ansible` (`pip install -r requirements.txt`) y red hasta los nodos |
| Secretos | Valores cifrados que el pipeline recibe como variables y no se muestran en el log | La clave `curso_ansible` del usuario `ansible` |
| Entornos | `dev`, `pre`, `prod` con reglas propias: aprobación, ramas permitidas, secretos distintos | Desplegar en prod solo desde `main` y con la aprobación de operaciones |
| Logs | La salida de cada paso, ligada al commit y a quien lo disparó | La salida de `make deploy`, guardada junto al commit que la produjo |
| Disparadores | Eventos de Git, ejecución manual con parámetros, programación (cron) | Validar en cada PR; desplegar a mano con `VERSION=1.1.0` |

El pipeline reutiliza lo que el proyecto ya tiene: el `Makefile` con `lint`, `check` y `deploy`, y la
confirmación `CONFIRMAR=si` para prod.

### GitHub Actions

Un despliegue manual a prod, con la versión como parámetro y el entorno `prod` protegido (fragmento de
referencia; el workflow completo se construye en el M12):

```yaml
# .github/workflows/desplegar.yml (fragmento)
on:
  workflow_dispatch:
    inputs:
      version:
        description: Versión del portal
        type: choice
        options: ["1.0.0", "1.1.0", "1.2.0"]

jobs:
  desplegar:
    runs-on: ubuntu-24.04
    environment: prod            # reglas del entorno: revisores obligatorios, solo rama main
    steps:
      - uses: actions/checkout@v4
      - run: pip install -r requirements.txt
      - name: Instalar la clave SSH desde el secreto del entorno
        run: |
          install -d -m 700 ~/.ssh/curso-ansible
          printf '%s\n' "${{ secrets.CLAVE_SSH }}" > ~/.ssh/curso-ansible/curso_ansible
          chmod 600 ~/.ssh/curso-ansible/curso_ansible
      - name: Desplegar
        working-directory: proyecto
        run: make deploy ENTORNO=prod VERSION=${{ inputs.version }} CONFIRMAR=si
```

| Elemento | Qué aporta |
|----------|------------|
| `workflow_dispatch` con `choice` | Un botón **Run workflow** con la lista cerrada de versiones, como la encuesta de AWX |
| `environment: prod` | El job espera a que un revisor del entorno lo apruebe; los secretos de `prod` solo llegan a jobs de ese entorno |
| `secrets.CLAVE_SSH` | La clave no está en el repositorio y GitHub la oculta (`***`) si aparece en el log |
| Pestaña **Actions** | Cada ejecución, con su log, el commit, quién la lanzó y quién la aprobó |

### GitLab CI

La misma idea en GitLab, con un job manual en un entorno protegido:

```yaml
# .gitlab-ci.yml (fragmento)
desplegar_prod:
  stage: deploy
  image: python:3.12
  environment:
    name: prod
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  before_script:
    - pip install -r requirements.txt
    - install -d -m 700 ~/.ssh/curso-ansible
    - cp "$CLAVE_SSH" ~/.ssh/curso-ansible/curso_ansible && chmod 600 ~/.ssh/curso-ansible/curso_ansible
  script:
    - cd proyecto && make deploy ENTORNO=prod VERSION="$VERSION" CONFIRMAR=si
```

| Elemento | Qué aporta |
|----------|------------|
| `when: manual` | El job no corre solo: espera a que alguien lo lance desde el pipeline |
| Entorno protegido `prod` | Solo los usuarios o grupos autorizados pueden lanzar o aprobar el despliegue |
| Variable `CLAVE_SSH` de tipo *File*, protegida y enmascarada | La clave llega como fichero solo a ramas protegidas y no se muestra en el log |
| `VERSION` como variable al lanzar | El equivalente al parámetro de la ejecución manual |

> [!WARNING]
> Un runner alojado en GitHub o GitLab está en Internet, no en la red de Tienda Norte. Para llegar a los
> servidores reales de prod hace falta un runner propio dentro de la red (o un bastión), y ese runner pasa a
> ser una máquina crítica: tiene la clave de prod en cada ejecución. En el M12 el problema no aparece porque
> el workflow levanta sus propios nodos de prueba dentro del runner con `scripts/nodos.sh up`.

## Qué se gana y qué se pierde

| Necesidad | Controlador (AWX / AAP) | CI/CD (GitHub Actions / GitLab CI) |
|-----------|-------------------------|------------------------------------|
| Inventario | Central, sincronizado, con fuentes dinámicas y vista de hosts | El fichero del commit; sin vista de hosts ni historial por host |
| Permisos | RBAC fino por objeto: lanzar sin editar, usar una credencial sin verla | Por repositorio y entorno: quien puede escribir en el repo puede cambiar el workflow en una rama |
| Credenciales | Tipos de credencial, cifrado, uso sin lectura; integración con almacenes externos | Secretos por repositorio o entorno; el job los recibe en claro |
| Programación | Schedules sobre cualquier plantilla | Cron del pipeline; válido para tareas sencillas |
| Auditoría | Jobs con eventos por host, quién lanzó y con qué variables; Activity Stream de cambios | Logs de pipeline y del entorno; sin eventos por host ni registro tan fino de cambios de permisos |
| Quién lo usa | Operaciones, guardias, otros equipos sin conocer Git | Quien trabaja con Git y pull requests |
| Simplicidad | Hay que instalar, actualizar y operar el controlador (o pagar AAP) | Ya existe: el repositorio y el CI de la empresa |
| Flujo Git | El proyecto apunta a una rama; el cambio y la ejecución van por caminos distintos | Cambio, revisión y despliegue en el mismo sitio, ligados al commit (GitOps) |
| Coste de entrada | Alto: plataforma, base de datos, Kubernetes o RHEL | Bajo: un fichero YAML en el repositorio |

> [!NOTE]
> No es una elección excluyente. Un reparto habitual: el pipeline valida cada PR (`make lint`, `make check`)
> y, al hacer merge a `main`, llama a la API del controlador para lanzar la plantilla «Desplegar portal».
> El flujo Git queda en el CI; inventario, credenciales, permisos y auditoría por host, en el controlador.

### Cuándo encaja cada uno en Tienda Norte

| Situación | Opción razonable |
|-----------|------------------|
| Un equipo pequeño que ya trabaja con PR y despliega lo que hay en `main` | Pipeline de GitHub Actions |
| Guardias que relanzan despliegues o reinicios sin tocar Git | Controlador con plantillas y permiso Execute |
| Auditoría que exige saber qué cambió en cada servidor y quién lo pidió | Controlador |
| Validar cada cambio antes de que llegue a `main` | Pipeline, en cualquier caso |
| Muchos equipos y entornos con permisos distintos sobre los mismos servidores | Controlador (AAP si se necesita soporte) |

La práctica de este camino está en el [M12 — Integración en entornos DevOps](../M12-integracion-devops/README.md):
un workflow que valida cada pull request, un despliegue manual con aprobación y un flujo GitOps básico, todo
en el fork y con el mismo `Makefile`.
