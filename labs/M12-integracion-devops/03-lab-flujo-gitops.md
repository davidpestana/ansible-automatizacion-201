# Lab — Flujo GitOps básico

[← Página anterior](02-lab-despliegue-desde-pipeline.md)

En Tienda Norte, prod sigue en la 1.0.0 y el equipo quiere promocionar la 1.1.0. Con GitOps nadie lanza un
despliegue: se cambia la versión en Git por pull request, el pipeline de validación la prueba y, al fusionar en
`main`, otro pipeline la aplica. Y si alguien toca un servidor a mano, la siguiente aplicación lo devuelve a lo
que dice Git.

### Objetivo

Un workflow `.github/workflows/aplicar.yml` que aplica `make site` en cada push a `main` que toca `proyecto/`, un
cambio de versión de prod llevado de la rama al runner por pull request, y una deriva manual en `prod-web1`
detectada con `make check` y corregida con `make site`.

### Punto de partida

- Codespace abierto sobre **tu fork**, con Actions habilitado (pestaña **Actions** → **I understand my workflows,
  go ahead and enable them**, si aparece).
- El paso 1 carga el estado `m12-03`: `proyecto/` como en `m12`, prod instalado en los nodos del Codespace con la
  1.0.0 y, si no lo tenías, `.github/workflows/validar.yml` (el pipeline de validación de pull requests del
  [Lab — Pipeline de validación](01-lab-pipeline-de-validacion.md)).
- No hace falta haber hecho los labs anteriores.

### En qué consiste

Subes el workflow de aplicación, promocionas la 1.1.0 a prod con un pull request y lo ves aplicarse en
**Actions**. Después haces en el Codespace lo que el pipeline haría con servidores reales, provocas una deriva en
`prod-web1` y la corriges desde Git.

> [!IMPORTANT]
> **Qué es simulado.** El runner aplica `main` sobre **sus** nodos, recién creados, no sobre los de tu Codespace.
> Los nodos del Codespace hacen aquí el papel de «los servidores reales»: lo que el pipeline les haría con acceso a
> ellos lo lanzas tú con el mismo comando.

### 1 — Prepara el punto de partida

**Acción** (terminal del Codespace, raíz del repo):

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m12-03
gh repo set-default "$GITHUB_REPOSITORY"
```

**Por qué:** deja prod del Codespace en la 1.0.0, tal como dice `inventories/prod/group_vars/all.yml`, y el
pipeline de validación en su sitio para que el pull request del paso 5 se valide.

**Resultado esperado:** el `PLAY RECAP` de prod con `failed=0` y
`Listo: proyecto/ en el punto de partida «m12-03»`. Si no tenías el workflow de validación, antes de esa línea
aparece `Creado .github/workflows/validar.yml`. `curl -s localhost:8080/estado.json` muestra `"version": "1.0.0"`.

### 2 — Escribe el workflow de aplicación

**Acción:** en una rama nueva (`git switch -c ci-aplicar`), crea `.github/workflows/aplicar.yml` en la raíz del repo:

```yaml
# .github/workflows/aplicar.yml
name: Aplicar main

on:
  push:
    branches: [main]
    paths:
      - "proyecto/**"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: aplicar-main
  cancel-in-progress: false

jobs:
  aplicar:
    name: Aplicar lo que hay en main
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

      - name: Levantar los nodos del runner
        run: bash scripts/nodos.sh up

      - name: Aplicar dev
        working-directory: proyecto
        run: make site ENTORNO=dev

      - name: Aplicar pre
        working-directory: proyecto
        run: make site ENTORNO=pre

      - name: Aplicar prod
        working-directory: proyecto
        run: make site ENTORNO=prod CONFIRMAR=si

      - name: Comprobar que prod sirve la versión de Git
        working-directory: proyecto
        run: |
          ESPERADA=$(sed -n 's/^portal_version: "\(.*\)"/\1/p' inventories/prod/group_vars/all.yml)
          curl -s localhost:8080/estado.json
          curl -s localhost:8080/estado.json | grep -q "\"version\": \"$ESPERADA\""
```

**Por qué:**

- `push` a `main` es el único disparador automático: lo que entra en `main` se aplica, y solo entra por pull
  request ya validado.
- `make site` (no `make deploy`): aplica el estado completo descrito en Git, versión incluida. Cada `make site`
  pasa antes por `make validar`.
- Los entornos van en orden dev → pre → prod: si dev falla, prod no se toca.
- `concurrency` encola dos merges seguidos en vez de aplicarlos a la vez.
- El último paso compara el portal con la versión escrita en `group_vars`: el pipeline comprueba que Git y el
  servidor dicen lo mismo.
- `workflow_dispatch` permite relanzarlo a mano desde **Run workflow**.

**Resultado esperado:** `python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/aplicar.yml")); print("YAML correcto")'`
imprime `YAML correcto`.

### 3 — Sube el workflow a `main`

**Acción:**

```bash
git add .github/workflows proyecto
git commit -m "Aplicar main con GitHub Actions"
git push -u origin ci-aplicar
gh pr create --base main --head ci-aplicar --title "Aplicar main con GitHub Actions" --body "Cada push a main que toca proyecto/ aplica site.yml."
gh pr merge ci-aplicar --merge --delete-branch
git switch main
git pull
```

**Por qué:** el workflow tiene que estar en `main` para reaccionar a los push a `main`.

**Resultado esperado:** **Actions** muestra el workflow **Aplicar main** en la lista de la izquierda. Si el merge
traía cambios en `proyecto/`, ya hay una primera ejecución; si no, lánzala con
`gh workflow run aplicar.yml` y espera a verla en verde con `gh run watch`.

### 4 — Propón la 1.1.0 para prod

**Acción:** crea la rama y cambia la versión de prod en Git:

```bash
git switch -c prod-1.1.0
```

```yaml
# proyecto/inventories/prod/group_vars/all.yml
portal_entorno: prod
portal_color: "#15803d"
portal_version: "1.1.0"
portal_db_host: prod-db1
```

Antes de subirlo, mira qué cambiaría en prod: `cd proyecto && make check ENTORNO=prod`.

**Por qué:** en GitOps la versión de prod no es un parámetro que alguien pasa a mano: es una línea de Git, con su
autor, su revisión y su historial. `make check` dice exactamente qué tocará el cambio.

**Resultado esperado:** el check enseña el enlace `current` cambiando de release en las dos web, sin tocar la
base de datos ni el balanceador:

```text
TASK [portal : Apuntar current a la release 1.1.0] *****************************
--- before
+++ after
@@ -1,4 +1,4 @@
 {
     "path": "/srv/portal/current",
-    "src": "/srv/portal/releases/1.0.0"
+    "src": "/srv/portal/releases/1.1.0"
 }
…
PLAY RECAP *********************************************************************
prod-db1                   : ok=8    changed=0    …
prod-lb1                   : ok=4    changed=0    …
```

### 5 — Llévalo por pull request

**Acción** (raíz del repo):

```bash
cd "$CODESPACE_VSCODE_FOLDER"
git commit -am "Promociona la 1.1.0 a prod"
git push -u origin prod-1.1.0
gh pr create --base main --head prod-1.1.0 --title "Promociona la 1.1.0 a prod" --body "portal_version 1.0.0 -> 1.1.0 en prod."
gh pr checks --watch
```

**Por qué:** el cambio toca `proyecto/`, así que `validar.yml` lo prueba (lint, syntax, `site` y `check` en pre)
antes de que nadie pueda fusionarlo. `aplicar.yml` no corre todavía: solo reacciona a `main`.

**Resultado esperado:** el check **Lint, syntax, site y check en pre** en verde. En **Actions** no hay ninguna
ejecución nueva de **Aplicar main**.

### 6 — Fusiona y mira cómo se aplica

**Acción:**

```bash
gh pr merge prod-1.1.0 --merge --delete-branch
gh run list --workflow=aplicar.yml --limit 1
gh run watch
```

**Por qué:** el merge es el despliegue. No hay un segundo paso manual: el push a `main` dispara la aplicación.

**Resultado esperado:** una ejecución nueva de **Aplicar main** con el título del merge. Termina en verde, y el
paso **Comprobar que prod sirve la versión de Git** imprime el `estado.json` del balanceador del runner con
`"version": "1.1.0"`.

### 7 — Haz en el Codespace lo que el pipeline haría con servidores reales

**Acción:**

```bash
git switch main
git pull
cd proyecto
make site ENTORNO=prod CONFIRMAR=si
curl -s localhost:8080/estado.json
```

**Por qué:** los nodos del Codespace hacen de servidores reales. Aplicar `main` sobre ellos es exactamente el paso
**Aplicar prod** del workflow.

**Resultado esperado:** `changed` en las tareas de la release de `prod-web1` y `prod-web2`, `failed=0` en todos, y
`"version": "1.1.0"` en el `curl`.

### 8 — Provoca una deriva

**Acción:** alguien «arregla» `prod-web1` a mano subiendo las conexiones de nginx, sin pasar por Git:

```bash
docker exec prod-web1 sed -i 's/worker_connections 768/worker_connections 1024/' /etc/nginx/nginx.conf
docker exec prod-web1 grep worker_connections /etc/nginx/nginx.conf
```

**Por qué:** es la situación de cada día: un cambio urgente en un servidor que no queda registrado en ningún sitio. Ahora
el servidor ya no es lo que dice Git.

**Resultado esperado:**

```text
    worker_connections 1024;
```

### 9 — Detecta la deriva sin tocar nada

**Acción:** `make check ENTORNO=prod`

**Por qué:** el modo check compara cada nodo con lo que describe Git y enseña las diferencias sin cambiarlas. Es
la forma de preguntar «¿alguien ha tocado prod?».

**Resultado esperado:** solo `prod-web1` tiene cambios pendientes, con el diff de `nginx.conf`:

```text
TASK [portal : Configurar nginx (nginx.conf)] **********************************
ok: [prod-web2]
--- before: /etc/nginx/nginx.conf
+++ after: …/nginx.conf.j2
@@ -5,7 +5,7 @@
 include /etc/nginx/modules-enabled/*.conf;
 
 events {
-    worker_connections 1024;
+    worker_connections 768;
 }
…
prod-web1                  : ok=12   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Los dos `changed` son la plantilla y el handler **Recargar nginx**. `prod-web2` tiene sus propias 2048 conexiones,
pero vienen de `inventories/prod/host_vars/prod-web2.yml`: eso no es deriva, está en Git.

### 10 — Devuelve prod al estado de Git

**Acción:**

```bash
make site ENTORNO=prod CONFIRMAR=si
docker exec prod-web1 grep worker_connections /etc/nginx/nginx.conf
make site ENTORNO=prod CONFIRMAR=si
```

**Por qué:** `make site` no distingue entre «primera instalación» y «alguien lo cambió»: deja cada nodo como dice
Git. La segunda pasada confirma que no queda nada por corregir.

**Resultado esperado:** la primera pasada, `prod-web1 … changed=2`; el `grep` vuelve a `worker_connections 768;`; la
segunda pasada, `changed=0` en los cuatro nodos:

```text
PLAY RECAP *********************************************************************
prod-db1                   : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

> [!NOTE]
> En el pipeline, esta corrección la haría una ejecución **programada** (`schedule`) de `aplicar.yml` contra los
> servidores reales, por ejemplo cada noche. En este curso los nodos del runner nacen limpios, así que una
> ejecución programada nunca encontraría deriva: lo ves aquí, en el Codespace.

## Comprueba tu entendimiento

**Git es la fuente de verdad**
`git log --oneline -3 -- proyecto/inventories/prod/group_vars/all.yml`
→ Aparece el commit «Promociona la 1.1.0 a prod»: quién cambió la versión de prod y cuándo, sin mirar ningún servidor.

**Un cambio que no toca `proyecto/` no se aplica**
Cambia una línea de `README.md` en `main` por pull request y fusiónalo.
→ En **Actions** no aparece ninguna ejecución nueva de **Aplicar main**.

**Una deriva deja rastro**
Repite el paso 8 y lanza `make check ENTORNO=prod`.
→ `prod-web1` con `changed=2` y el diff de `worker_connections`; el resto de nodos con `changed=0`.

## Reto

### 1 — Aplicar cada noche y a demanda

Haz que `aplicar.yml` también se ejecute solo cada día a las 06:00 UTC, además de en cada push a `main` y con
**Run workflow**.

<details>
<summary>Ver solución</summary>

Añade `schedule` a `on`:

```yaml
# .github/workflows/aplicar.yml (bloque on)
on:
  push:
    branches: [main]
    paths:
      - "proyecto/**"
  schedule:
    - cron: "0 6 * * *"
  workflow_dispatch:
```

`schedule` solo funciona con el fichero en la rama por defecto y usa UTC. GitHub puede retrasar las ejecuciones
programadas en momentos de carga y las desactiva en repositorios sin actividad durante meses. Con servidores
reales, una alternativa es programar `make check` en vez de `make site`: el job falla si hay `changed`, avisa de
la deriva y alguien decide si se corrige o si el cambio debe entrar en Git.

</details>

### 2 — Si las 1024 conexiones eran necesarias

El cambio manual del paso 8 respondía a un problema real: `prod-web1` necesita 1024 conexiones. Llévalo a prod de
forma que la siguiente aplicación no lo deshaga.

<details>
<summary>Ver solución</summary>

Por Git, igual que `prod-web2`: crea `proyecto/inventories/prod/host_vars/prod-web1.yml` con

```yaml
# proyecto/inventories/prod/host_vars/prod-web1.yml
portal_worker_connections: 1024
```

rama, pull request (validado por `validar.yml`) y merge (aplicado por `aplicar.yml`). En el Codespace,
`make check ENTORNO=prod` antes del `make site` muestra el diff de `768` a `1024` solo en `prod-web1`; después,
`make site` lo aplica y la siguiente pasada da `changed=0`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| Tras el merge no aparece ninguna ejecución de **Aplicar main** | `aplicar.yml` no estaba en `main` antes del merge, o el cambio no toca `proyecto/` | Fusiona primero el workflow (paso 3); para relanzar, `gh workflow run aplicar.yml` |
| **Aplicar prod** falla con `prod pide CONFIRMAR=si` | Falta `CONFIRMAR=si` en la línea de prod | Añádelo: la aprobación ya la dio la revisión del pull request |
| **Comprobar que prod sirve la versión de Git** falla aunque `Aplicar prod` está en verde | `portal_version` en `group_vars` sin comillas o con otro formato, y el `sed` no lo encuentra | Deja la línea como `portal_version: "1.1.0"`, entre comillas dobles |
| `make check ENTORNO=prod` no enseña la deriva | El cambio manual se hizo en un fichero que el proyecto no gestiona | Solo se corrige lo que Git describe; `nginx.conf` sí lo gestiona el rol `portal` |
| El pull request de la versión se puede fusionar con el check aún en amarillo | El check no es obligatorio en `main` | Haz obligatorio el check de validación con una regla de rama (reto del [Lab — Pipeline de validación](01-lab-pipeline-de-validacion.md)) |
| `docker exec prod-web1 …` responde `No such container` | Los nodos no están levantados (Codespace reanudado) | `scripts/nodos.sh up` desde la raíz del repo |
