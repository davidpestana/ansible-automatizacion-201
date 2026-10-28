# Ansible en un pipeline

[← Página anterior](README.md) · [Siguiente página →](01-lab-pipeline-de-validacion.md)

Hasta ahora, en Tienda Norte, `make validar` y `make check` los lanza una persona desde su Codespace, y el
resultado solo lo ve ella. En esta demostración, el mismo proyecto del portal se valida **solo**, en GitHub
Actions, cada vez que alguien abre un pull request: un runner levanta nodos de prueba, ejecuta el `Makefile` y
deja el log de cada paso en la pestaña **Actions**, enlazado al commit.

## Punto de partida

- Repositorio: tu fork del curso en GitHub, con **Actions** habilitado (en un fork, la pestaña **Actions** pide
  confirmarlo la primera vez con **I understand my workflows, go ahead and enable them**).
- Proyecto: `proyecto/` en el estado `m12` (roles, `site.yml`, `deploy.yml`, `Makefile` y `.ansible-lint`).
  Desde la raíz del repo: `scripts/partida.sh m12`.
- Workflow: `.github/workflows/validar.yml` en la raíz del repo, con el contenido que se muestra abajo (es el
  que se construye en el [Lab — Pipeline de validación](01-lab-pipeline-de-validacion.md)).
- Nodos: los del runner. No hace falta tener nada levantado en el Codespace para que el pipeline funcione.

## Recorrido

1. **El fichero del workflow.** Vive en `.github/workflows/` de la raíz del repositorio, no en `proyecto/`:
   GitHub solo busca workflows ahí. Este es el de validación del portal:

   ```yaml
   # .github/workflows/validar.yml
   name: Validar proyecto Ansible

   on:
     pull_request:
       branches: [main]
       paths:
         - "proyecto/**"
         - ".github/workflows/validar.yml"
     push:
       branches: [main]
       paths:
         - "proyecto/**"
         - ".github/workflows/validar.yml"

   permissions:
     contents: read

   jobs:
     validar:
       name: Lint, syntax, site y check en pre
       runs-on: ubuntu-24.04
       env:
         ANSIBLE_FORCE_COLOR: "1"
       steps:
         - name: Descargar el repositorio
           uses: actions/checkout@v4

         - name: Preparar Python 3.12
           uses: actions/setup-python@v5
           with:
             python-version: "3.12"
             cache: pip

         - name: Instalar Ansible y ansible-lint
           run: pip install -r requirements.txt

         - name: Levantar los nodos de prueba
           run: bash scripts/nodos.sh up

         - name: Lint y syntax-check
           working-directory: proyecto
           run: make validar

         - name: Aplicar site.yml en pre
           working-directory: proyecto
           run: make site ENTORNO=pre

         - name: Simular en pre (check)
           working-directory: proyecto
           run: make check ENTORNO=pre
   ```

   `on` dice cuándo corre: en cada pull request contra `main` y en cada push a `main`, pero solo si el cambio toca
   `proyecto/` o el propio workflow. Un cambio en `labs/` no gasta un runner. Las versiones de las actions están
   fijadas (`@v4`, `@v5`) para que el pipeline no cambie solo de un día para otro.

2. **El runner.** `runs-on: ubuntu-24.04` pide a GitHub una máquina virtual Ubuntu nueva, que hace de **nodo de
   control** igual que el Codespace. Nace vacía: por eso los primeros pasos descargan el repositorio
   (`actions/checkout`), preparan Python 3.12 e instalan exactamente las versiones de `requirements.txt`
   (`ansible==13.8.0`, `ansible-lint==26.9.0`). Al terminar, la máquina se destruye.

3. **Los nodos de prueba.** El runner trae Docker, así que `bash scripts/nodos.sh up` hace lo mismo que al
   arrancar el Codespace: crea la clave del curso en `~/.ssh/curso-ansible/`, construye la imagen de
   `infra/nodo/` y levanta los seis nodos en la red 172.30.0.0/24. `infra/ssh_config` y `proyecto/ansible.cfg`
   valen sin tocar nada. En el log, el paso termina con las seis líneas de `scripts/nodos.sh estado`:

   ```text
   dev-web1   SSH ok
   pre-web1   SSH ok
   prod-lb1   SSH ok
   prod-web1  SSH ok
   prod-web2  SSH ok
   prod-db1   SSH ok
   ```

4. **Validar.** El paso **Lint y syntax-check** ejecuta `make validar` desde `proyecto/` (`working-directory`),
   porque ahí está `ansible.cfg`. Su log es el mismo que en el terminal:

   ```text
   ansible-lint site.yml deploy.yml

   Passed: 0 failure(s), 0 warning(s) in 18 files processed of 18 encountered. Profile 'production' was required, and it passed.
   …
   playbook: site.yml

   playbook: deploy.yml
   ```

5. **Primero aplicar, después simular.** Los nodos del runner no tienen nginx. Un `make check` sobre un nodo
   vacío falla en la primera tarea, porque en modo check `apt` no instala y la lista de paquetes está sin
   actualizar:

   ```text
   TASK [portal : Instalar nginx] *************************************************
   [ERROR]: Task failed: Module failed: No package matching 'nginx' is available
   …
   fatal: [dev-web1]: FAILED! => {"changed": false, "msg": "No package matching 'nginx' is available"}
   ```

   Por eso el workflow aplica antes `make site ENTORNO=pre` (en un nodo vacío, `ok=12 changed=11`) y después
   lanza `make check ENTORNO=pre`, que es la prueba de que el proyecto es idempotente: una segunda pasada, en
   simulación, no cambiaría nada.

   ```text
   PLAY RECAP *********************************************************************
   pre-web1                   : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
   ```

6. **Dónde se ve cada paso.** En la pestaña **Actions** del repositorio, la lista de la izquierda muestra el
   workflow **Validar proyecto Ansible**; cada ejecución lleva el título del commit o del pull request que la
   disparó. Al abrir una ejecución aparece el job **Lint, syntax, site y check en pre** y, dentro, un bloque
   plegable por cada `name:` de `steps`, con su log completo y su duración. `ANSIBLE_FORCE_COLOR: "1"` hace que
   el log conserve los colores de Ansible (verde `ok`, amarillo `changed`, rojo `fatal`), que en un runner sin
   terminal se perderían.

7. **El resultado en el pull request.** En la pestaña **Conversation** del pull request, al final, aparece el
   check **Validar proyecto Ansible / Lint, syntax, site y check en pre** con un círculo amarillo mientras corre,
   y después un ✓ verde o una ✗ roja. **Details** lleva directamente al log del paso que ha fallado. Desde el
   terminal, `gh pr checks` muestra lo mismo.

> [!NOTE]
> El pipeline no sustituye al `Makefile`: lo **usa**. Si mañana el equipo cambia lo que hace `make validar`, el
> pipeline lo hereda sin tocar el YAML. Y si un paso falla en Actions, se reproduce en el Codespace con el mismo
> comando.

## Qué queda visto

Un workflow de GitHub Actions que convierte el runner en nodo de control, levanta los nodos del portal con
`scripts/nodos.sh up`, ejecuta `make validar`, `make site ENTORNO=pre` y `make check ENTORNO=pre`, y deja cada
paso a la vista en **Actions** y en el pull request. En el
[Lab — Pipeline de validación](01-lab-pipeline-de-validacion.md) lo creas en tu fork, lo ves fallar con un
error de lint y lo pones en verde; se puede hacer sin haber seguido esta demostración.
