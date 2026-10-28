# Lab — Makefile

[← Página anterior](00-estandarizar-y-organizar.md) · [Siguiente página →](02-lab-ansible-lint.md)

En el equipo de operaciones de Tienda Norte cada persona lanza `ansible-playbook` con sus opciones: unos olvidan el
`-i`, otros despliegan en prod sin simular antes. En este lab escribes el `Makefile` de `proyecto/`: un único punto
de entrada con el entorno como parámetro, objetivos para comprobar, validar y desplegar, y una guarda que no deja
tocar prod sin confirmarlo.

### Objetivo

`proyecto/Makefile` con los objetivos `ayuda`, `ping`, `lint`, `syntax`, `check`, `validar`, `site` y `deploy`,
probado contra pre y prod: `make deploy ENTORNO=prod VERSION=1.1.0` se para sin `CONFIRMAR=si` y despliega con él.

### Punto de partida

- Terminal del Codespace, en la raíz del repositorio.
- Estado: proyecto completo (`site.yml` = base de datos + web + balanceador, `deploy.yml` por tandas), **sin**
  `Makefile`, y prod con el portal instalado. Lo deja así el paso 1.
- Herramientas: `make`, `ansible-playbook` y `ansible-lint`, ya instaladas en el Codespace.

### En qué consiste

Escribes el `Makefile` en cuatro tandas y ejecutas cada objetivo según lo añades. No cambias roles ni playbooks:
el `Makefile` solo fija cómo se llaman. Al final despliegas la 1.1.0 en prod a través de `make`.

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, en la raíz del repositorio
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m10
cd proyecto
make ayuda
```

**Por qué:** deja `proyecto/` con el proyecto completo y los nodos de prod con el portal aplicado, sin depender de
módulos anteriores. El último comando comprueba que aún no hay `Makefile`.

**Resultado esperado:** `partida.sh` aplica `site.yml` en prod y termina con el resumen y la ruta del proyecto:

```text
Preparando los nodos para m10…
PLAY RECAP *********************************************************************
prod-db1                   : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

Listo: proyecto/ en el punto de partida «m10» (lo anterior está en proyecto.anterior/).
```

Si los nodos estaban recién creados, verás `changed` mayor que 0: es la primera instalación. Y `make` aún no
sabe qué hacer:

```text
make: *** No rule to make target 'ayuda'.  Stop.
```

> [!WARNING]
> `scripts/partida.sh` sustituye `proyecto/` entero (lo anterior queda en `proyecto.anterior/`). Si tenías trabajo
> propio en `proyecto/`, haz commit antes de cargar el punto de partida.

### 2 — Escribe las variables y el objetivo `ayuda`

**Acción:** crea `proyecto/Makefile` con este contenido. Las líneas de receta (debajo de `ayuda:`) empiezan por
un **tabulador**, no por espacios:

```makefile
# proyecto/Makefile
# Punto de entrada del proyecto: todas las ejecuciones pasan por aquí.
#   make check ENTORNO=pre            simula el site.yml sin cambiar nada (nodos ya instalados)
#   make deploy ENTORNO=prod VERSION=1.1.0 CONFIRMAR=si
ENTORNO ?= dev
VERSION ?=
INVENTARIO := inventories/$(ENTORNO)/hosts.yml
PLAYBOOKS := site.yml deploy.yml

.PHONY: ayuda lint syntax check validar site deploy ping confirmar

ayuda:
	@echo "Objetivos: lint syntax check validar site deploy ping  (ENTORNO=dev|pre|prod, VERSION=x.y.z)"
```

Después ejecuta:

```bash
# Terminal del Codespace, en proyecto/
make ayuda
make
```

**Por qué:**

| Línea | Qué hace |
|-------|----------|
| `ENTORNO ?= dev` | Valor por defecto: si nadie pasa `ENTORNO=…`, se trabaja en dev, nunca en prod por despiste |
| `VERSION ?=` | Vacía por defecto; `deploy` la exigirá |
| `INVENTARIO := inventories/$(ENTORNO)/hosts.yml` | El entorno elige el inventario; nadie escribe `-i` a mano |
| `PLAYBOOKS := …` | Los playbooks que se validan |
| `.PHONY:` | Estos objetivos no son ficheros: `make` los ejecuta siempre, aunque exista un fichero llamado `check` |
| `@echo` | La `@` evita que `make` imprima el comando antes de ejecutarlo |

El primer objetivo del fichero es el que se ejecuta con `make` a secas: por eso `ayuda` va el primero.

**Resultado esperado:** las dos órdenes imprimen la misma línea:

```text
Objetivos: lint syntax check validar site deploy ping  (ENTORNO=dev|pre|prod, VERSION=x.y.z)
```

La línea anuncia objetivos que aún no existen: los añades en los pasos siguientes.

> [!TIP]
> VS Code respeta los tabuladores en los ficheros `Makefile`. Si copias el bloque y `make` responde
> `missing separator`, la receta ha quedado con espacios: borra la sangría y pulsa <kbd>Tab</kbd>.

### 3 — Añade `ping` y pruébalo en pre

**Acción:** añade al final de `proyecto/Makefile` (con tabulador delante de `ansible`):

```makefile
# proyecto/Makefile (añadir al final)

ping:
	ansible all -i $(INVENTARIO) -m ansible.builtin.ping
```

Y ejecútalo pasando el entorno:

```bash
# Terminal del Codespace, en proyecto/
make ping ENTORNO=pre
```

**Por qué:** `ENTORNO=pre` en la línea de `make` sustituye al valor por defecto, y `$(INVENTARIO)` pasa a ser
`inventories/pre/hosts.yml`. Es la forma más barata de comprobar que el entorno elegido responde.

**Resultado esperado:** `make` imprime el comando que lanza (sin `@`, se ve) y después la respuesta de `pre-web1`:

```text
ansible all -i inventories/pre/hosts.yml -m ansible.builtin.ping
pre-web1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
```

Prueba también `make ping` sin parámetro: el comando sale con `inventories/dev/hosts.yml` y responde `dev-web1`.

### 4 — Añade `lint`, `syntax` y `check`

**Acción:** añade al final de `proyecto/Makefile`:

```makefile
# proyecto/Makefile (añadir al final)

lint:
	ansible-lint $(PLAYBOOKS)

syntax:
	@for p in $(PLAYBOOKS); do ansible-playbook -i $(INVENTARIO) $$p --syntax-check || exit 1; done

check:
	ansible-playbook -i $(INVENTARIO) site.yml --check --diff
```

Y ejecuta los tres:

```bash
# Terminal del Codespace, en proyecto/
make lint
make syntax ENTORNO=prod
make check ENTORNO=prod
```

**Por qué:** son las tres comprobaciones que se hacen antes de tocar un entorno. En `syntax`, `$$p` es la variable
`p` del bucle de shell: `make` usa `$` para sus propias variables, así que la de shell se escribe con `$$`. El
`|| exit 1` corta el bucle en cuanto un playbook falla.

**Resultado esperado:** `make lint` termina con `Passed` (el proyecto ya está limpio):

```text
ansible-lint site.yml deploy.yml

Passed: 0 failure(s), 0 warning(s) in 18 files processed of 18 encountered. Last profile that met the validation criteria was 'production'.
```

`make syntax ENTORNO=prod` nombra los dos playbooks sin errores:

```text
playbook: site.yml

playbook: deploy.yml
```

Y `make check ENTORNO=prod` simula todo `site.yml` sobre prod sin cambiar nada: como prod ya está aplicado, todo
sale `ok` (recortado):

```text
ansible-playbook -i inventories/prod/hosts.yml site.yml --check --diff

PLAY [Base de datos del portal] ************************************************
…
PLAY RECAP *********************************************************************
prod-db1                   : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

> [!NOTE]
> `ansible-lint` puede añadir al final un aviso `A new release of ansible-lint is available`. Es informativo: el
> curso fija la versión en `requirements.txt` y no hace falta actualizar.

### 5 — Añade `validar`, `site`, `deploy` y la guarda de prod

**Acción:** añade al final de `proyecto/Makefile`:

```makefile
# proyecto/Makefile (añadir al final)

validar: lint syntax

site: validar confirmar
	ansible-playbook -i $(INVENTARIO) site.yml

deploy: validar check confirmar
	@test -n "$(VERSION)" || { echo "Falta VERSION=x.y.z"; exit 2; }
	ansible-playbook -i $(INVENTARIO) deploy.yml -e portal_version=$(VERSION)

confirmar:
	@if [ "$(ENTORNO)" = "prod" ] && [ "$(CONFIRMAR)" != "si" ]; then \
	  echo "prod pide CONFIRMAR=si"; exit 2; fi
```

Antes de lanzar nada, mira qué haría `deploy`:

```bash
# Terminal del Codespace, en proyecto/
make -n deploy ENTORNO=prod VERSION=1.1.0
```

**Por qué:** lo que va detrás de los dos puntos son **requisitos**: `make` los ejecuta en orden antes de la receta
y, si uno falla, se para. Así `deploy` no puede saltarse el lint, la sintaxis ni la simulación, y `confirmar` es
un objetivo sin receta propia de Ansible que solo corta si el entorno es prod y falta `CONFIRMAR=si`. La opción
`-n` imprime los comandos sin ejecutarlos.

**Resultado esperado:** la cadena completa, en el orden en que se ejecutará:

```text
ansible-lint site.yml deploy.yml
for p in site.yml deploy.yml; do ansible-playbook -i inventories/prod/hosts.yml $p --syntax-check || exit 1; done
ansible-playbook -i inventories/prod/hosts.yml site.yml --check --diff
if [ "prod" = "prod" ] && [ "" != "si" ]; then \
  echo "prod pide CONFIRMAR=si"; exit 2; fi
test -n "1.1.0" || { echo "Falta VERSION=x.y.z"; exit 2; }
ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.1.0
```

### 6 — Intenta desplegar en prod sin confirmar

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
make deploy ENTORNO=prod VERSION=1.1.0
```

**Por qué:** comprueba que la guarda funciona: nadie aplica en prod por un comando copiado de dev.

**Resultado esperado:** pasan el lint, la sintaxis y el check y, justo antes de desplegar, `make` se para
(recortado):

```text
ansible-lint site.yml deploy.yml

Passed: 0 failure(s), 0 warning(s) in 18 files processed of 18 encountered. Last profile that met the validation criteria was 'production'.

playbook: site.yml

playbook: deploy.yml
ansible-playbook -i inventories/prod/hosts.yml site.yml --check --diff
…
PLAY RECAP *********************************************************************
prod-db1                   : ok=8    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-lb1                   : ok=4    changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

prod pide CONFIRMAR=si
make: *** [Makefile:36: confirmar] Error 2
```

`curl -s localhost:8080/estado.json` sigue diciendo `"version": "1.0.0"`.

### 7 — Despliega la 1.1.0 en prod confirmando

**Acción:**

```bash
# Terminal del Codespace, en proyecto/
make deploy ENTORNO=prod VERSION=1.1.0 CONFIRMAR=si
curl -s localhost:8080/estado.json
```

**Por qué:** con la confirmación explícita, `make` lanza `deploy.yml` con la versión pedida: una web cada vez,
sacándola del balanceador mientras se actualiza.

**Resultado esperado:** tras las comprobaciones, el despliegue recorre `prod-web1` y después `prod-web2`
(recortado):

```text
ansible-playbook -i inventories/prod/hosts.yml deploy.yml -e portal_version=1.1.0

PLAY [Desplegar el portal 1.1.0] ***********************************************
…
TASK [portal : Apuntar current a la release 1.1.0] *****************************
changed: [prod-web1]
…
TASK [Verificar que el portal responde] ****************************************
ok: [prod-web1]
…
PLAY RECAP *********************************************************************
prod-web1                  : ok=13   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=13   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Y el balanceador ya sirve la 1.1.0:

```text
{
  "host": "prod-web1",
  "entorno": "prod",
  "version": "1.1.0",
  "color": "#15803d",
  "db": "prod-db1"
}
```

El campo `host` puede salir `prod-web2`: el balanceador reparte entre las dos.

## Comprueba tu entendimiento

**El entorno por defecto es dev**
Ejecuta `make -n check`.
→ El comando sale con `-i inventories/dev/hosts.yml`: sin `ENTORNO`, nunca se apunta a prod.

**La guarda solo afecta a prod**
Ejecuta `make -n site ENTORNO=pre`.
→ Salen el lint, la sintaxis, el `if` de `confirmar` con `[ "pre" = "prod" ]` y el `ansible-playbook` de `site.yml`:
en pre no hace falta `CONFIRMAR=si`.

**`deploy` exige versión**
Ejecuta `make deploy ENTORNO=prod CONFIRMAR=si` (sin `VERSION`).
→ Tras las comprobaciones, `Falta VERSION=x.y.z` y `make: *** [Makefile:32: deploy] Error 2`. No se despliega nada.

## Reto

### 1 — Un objetivo para ver la versión publicada

Añade un objetivo `version` que muestre el `estado.json` de cada web del entorno elegido, de modo que
`make version ENTORNO=prod` enseñe la versión de `prod-web1` y `prod-web2`. Pista: `ansible.builtin.uri` o un
`curl` con el módulo `ansible.builtin.command` en modo ad hoc, limitado al grupo `web`.

<details>
<summary>Ver solución</summary>

Añade `version` a la línea `.PHONY` y este objetivo (con tabulador):

```makefile
# proyecto/Makefile
version:
	ansible web -i $(INVENTARIO) -m ansible.builtin.command -a "curl -s localhost/estado.json"
```

`make version ENTORNO=prod` imprime `prod-web1 | CHANGED | rc=0 >>` y el JSON de cada web, con
`"version": "1.1.0"` tras el paso 7. El `CHANGED` es porque `ansible.builtin.command` siempre se da por
cambiado; en realidad es una lectura, así que no hace falta pasar por `confirmar`. Añádelo también al texto de `ayuda`.

</details>

### 2 — ¿Por qué `deploy` no depende de `site`?

Explica qué pasaría si la línea fuera `deploy: site check confirmar`.

<details>
<summary>Ver solución</summary>

`site` aplica `site.yml` entero, que publica la versión de `group_vars` (`1.0.0` en prod). El despliegue
empezaría devolviendo prod a la 1.0.0 y después pasaría a la versión pedida: dos cambios en prod en lugar de uno.
`deploy` necesita comprobar (`validar`, `check`), no aplicar.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `Makefile:15: *** missing separator.  Stop.` | La receta está sangrada con espacios | Borra la sangría y pon un tabulador |
| `make ayuda` responde `Nothing to be done for 'ayuda'.` | La línea del `@echo` tiene espacios en vez de tabulador y `make` la lee como otra regla (por los `:` del texto) | Tabulador delante de `@echo` |
| `make: *** No rule to make target 'ayuda'.  Stop.` | Lanzas `make` fuera de `proyecto/` o el fichero no se llama `Makefile` | `cd proyecto` y comprueba el nombre con `ls` |
| `make ping ENTORNO=Pre` avisa `Unable to parse …/inventories/Pre/hosts.yml as an inventory source` y `provided hosts list is empty` | El entorno se escribe en minúsculas: es el nombre de la carpeta | `ENTORNO=pre` |
| `prod pide CONFIRMAR=si` | Es la guarda: en prod hay que confirmar | Añade `CONFIRMAR=si` cuando de verdad quieras aplicar |
| `make syntax` responde `usage: ansible-playbook [-h] [--version] …` | Escribiste `$p` en vez de `$$p`: `make` lo sustituye por su variable `p`, vacía, y `ansible-playbook` se queda sin playbook | En recetas de `make`, la variable de shell va con `$$` |
