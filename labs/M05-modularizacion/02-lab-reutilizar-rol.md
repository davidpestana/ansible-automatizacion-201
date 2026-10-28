# Lab — Reutilizar el rol

[← Página anterior](01-lab-crear-rol.md) · [Siguiente página →](03-buenas-practicas.md)

Tienda Norte ya tiene el rol `portal` para sus servidores web. Ahora toca sacarle partido: el mismo rol tiene que
servir para dev, pre y prod, aceptar otra versión cuando alguien quiera probarla, y el balanceador de prod
necesita su propio rol con el mismo patrón. En este lab reutilizas el rol cambiando solo parámetros, creas
`portal_lb` y montas el portal completo de prod con un único `site.yml`.

### Objetivo

El rol `portal` aplicado con otros valores (otra versión, otro entorno) sin tocar su código, el rol `portal_lb` en
`prod-lb1` y `site.yml` desplegando prod entero, con el balanceador repartiendo entre `prod-web1` y `prod-web2`.

### Punto de partida

- Terminal del Codespace. Nodos levantados (`scripts/nodos.sh estado` da seis líneas `SSH ok`).
- Estado: `proyecto/` con el rol `roles/portal` y `web.yml` (lo que deja el lab anterior). El paso 1 lo carga.
- Nodos: da igual cómo estén; cada paso lleva el nodo a su estado.

### En qué consiste

Primero cambias el comportamiento del rol desde fuera: con `-e` y con otro inventario. Después creas `portal_lb`
con `ansible-galaxy role init`, su plantilla y sus defaults, escribes `lb.yml` y `site.yml` con
`ansible.builtin.import_playbook`, y compruebas el balanceo con la cabecera `X-Servidor`. No tocas el rol `portal`.

### 1 — Carga el punto de partida

**Acción:**

```bash
# Terminal del Codespace, raíz del repo
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m05-02
cd proyecto
```

**Por qué:** te deja el rol `portal` ya creado, aunque no hayas hecho el lab anterior.

**Resultado esperado:** `Listo: proyecto/ en el punto de partida «m05-02» …` y `ls roles` muestra `portal`.

### 2 — Deja dev en su versión

**Acción:**

```bash
ansible-playbook web.yml
```

**Por qué:** partes de un `dev-web1` conocido: el portal 1.1.0 que pide `inventories/dev/group_vars/all.yml`.

**Resultado esperado:** `ok=12 changed=11` si el nodo estaba vacío; `ok=11 changed=0 … skipped=1` si ya tenía el
portal.

### 3 — Cambia la versión desde la línea de comandos

**Acción:**

```bash
ansible-playbook web.yml -e portal_version=1.0.0
curl -s localhost:8081/estado.json
```

**Por qué:** alguien de soporte quiere ver en dev cómo era la 1.0.0 que corre en prod. No hace falta tocar el rol
ni el inventario: `-e` tiene la prioridad más alta y el rol hace el resto.

**Resultado esperado:** solo cambian las tareas de la release; la configuración de nginx queda igual:

```text
TASK [portal : Crear la carpeta de la release] *********************************
changed: [dev-web1]

TASK [portal : Copiar la release 1.0.0] ****************************************
changed: [dev-web1]

TASK [portal : Apuntar current a la release 1.0.0] *****************************
changed: [dev-web1]

TASK [portal : Publicar el estado del nodo] ************************************
changed: [dev-web1]
…
PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=4    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

```text
{
  "host": "dev-web1",
  "entorno": "dev",
  "version": "1.0.0",
  "color": "#2563eb",
  "db": ""
}
```

### 4 — Vuelve dev a la versión del inventario

**Acción:**

```bash
ansible-playbook web.yml
curl -s localhost:8081/estado.json
```

**Por qué:** sin `-e`, manda otra vez el `group_vars` de dev. La 1.1.0 sigue en el nodo, así que basta con mover el
enlace `current`.

**Resultado esperado:** una sola tarea cambia y el estado vuelve a `1.1.0`:

```text
TASK [portal : Apuntar current a la release 1.1.0] *****************************
changed: [dev-web1]
…
PLAY RECAP *********************************************************************
dev-web1                   : ok=11   changed=1    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

```text
{
  "host": "dev-web1",
  "entorno": "dev",
  "version": "1.1.0",
  "color": "#2563eb",
  "db": ""
}
```

### 5 — Aplica el mismo rol en pre

**Acción:**

```bash
ansible-playbook -i inventories/pre/hosts.yml web.yml
curl -s localhost:8082/estado.json
```

**Por qué:** es la reutilización que más se usa: el mismo `web.yml` y el mismo rol, otro inventario. Pre trae su
versión y su color en su `group_vars`.

**Resultado esperado:** `pre-web1 : ok=12 changed=11` la primera vez (o `changed=0` si ya lo tenía) y el estado de
pre, en naranja y con la 1.0.0:

```text
{
  "host": "pre-web1",
  "entorno": "pre",
  "version": "1.0.0",
  "color": "#d97706",
  "db": ""
}
```

### 6 — Genera el esqueleto del rol del balanceador

**Acción:**

```bash
ansible-galaxy role init --init-path roles portal_lb
rm -rf roles/portal_lb/{files,handlers,tests,vars,README.md}
```

**Por qué:** el balanceador es otra responsabilidad (no sirve el portal, reparte peticiones), así que va en su
propio rol, con el mismo patrón que `portal`. Se llama `portal_lb` y sus variables `portal_lb_*`, para cumplir el
prefijo que exige ansible-lint.

**Resultado esperado:** `- Role portal_lb was created successfully` y `ls roles/portal_lb` muestra
`defaults  meta  tasks  templates`.

### 7 — Escribe los defaults del balanceador

**Acción:** sustituye todo el contenido de `roles/portal_lb/defaults/main.yml` por:

```yaml
# proyecto/roles/portal_lb/defaults/main.yml
portal_lb_backends: "{{ groups['web'] | default([]) }}"
portal_lb_fuera: []
```

**Por qué:** por defecto el balanceador reparte entre todos los hosts del grupo `web` del inventario que se use.
`portal_lb_fuera` es la lista de nodos que se marcan como fuera de servicio; vacía de momento, la usarán los
despliegues escalonados.

**Resultado esperado:** dos líneas, las dos con el prefijo `portal_lb_`.

### 8 — Escribe la plantilla del balanceador

**Acción:** crea `roles/portal_lb/templates/balanceador.conf.j2`:

```jinja
# proyecto/roles/portal_lb/templates/balanceador.conf.j2
# {{ ansible_managed }}
upstream portal {
    zone portal 64k;
{% for web in portal_lb_backends %}
    server {{ web }}:80{{ ' down' if web in portal_lb_fuera else '' }};
{% endfor %}
}

server {
    listen 80 default_server;
    location / {
        proxy_pass http://portal;
        add_header X-Servidor $upstream_addr always;
    }
}
```

**Por qué:** la lista de servidores sale del inventario, no está escrita a mano. La cabecera `X-Servidor` dice qué
web ha contestado cada petición: es lo que usarás para ver el reparto.

**Resultado esperado:** `ls roles/portal_lb/templates` muestra `balanceador.conf.j2`.

### 9 — Escribe las tareas del balanceador

**Acción:** crea `roles/portal_lb/tasks/balancear.yml`:

```yaml
# proyecto/roles/portal_lb/tasks/balancear.yml
- name: Actualizar los servidores del balanceador
  ansible.builtin.template:
    src: balanceador.conf.j2
    dest: /etc/nginx/sites-available/default
    mode: "0644"
  register: portal_lb_conf

# Sin handler a propósito: deploy.yml incluye este fichero con delegate_to al balanceador,
# y un handler se ejecutaría en el nodo web que lo notifica, no en el balanceador.
- name: Recargar el balanceador  # noqa: no-handler
  ansible.builtin.service:
    name: nginx
    state: reloaded
  when: portal_lb_conf is changed
```

Y sustituye todo el contenido de `roles/portal_lb/tasks/main.yml` por:

```yaml
# proyecto/roles/portal_lb/tasks/main.yml
- name: Instalar nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: true
    cache_valid_time: 3600

- name: Arrancar nginx
  ansible.builtin.service:
    name: nginx
    state: started

- name: Configurar el balanceador
  ansible.builtin.import_tasks: balancear.yml
```

**Por qué:** el mismo reparto que en `portal`: `main.yml` instala, y un fichero aparte (`balancear.yml`) hace lo
que se repetirá cada vez que cambie la lista de servidores. El comentario anticipa su uso en los despliegues por
fases del M07; hoy basta con saber que recarga nginx solo si la plantilla cambia.

**Resultado esperado:** `ls roles/portal_lb/tasks` muestra `balancear.yml  main.yml`.

### 10 — Describe el rol del balanceador

**Acción:** sustituye todo el contenido de `roles/portal_lb/meta/main.yml` por:

```yaml
# proyecto/roles/portal_lb/meta/main.yml
galaxy_info:
  author: Operaciones Tienda Norte
  description: Balanceador nginx del portal de pedidos
  license: MIT
  min_ansible_version: "2.18"
  platforms:
    - name: Debian
      versions: [trixie]
dependencies: []
```

**Por qué:** `portal_lb` no depende de `portal`: el balanceador no sirve el portal, solo reparte hacia los web.

**Resultado esperado:** el fichero no conserva ningún valor de ejemplo del esqueleto.

### 11 — Escribe `lb.yml` y `site.yml`

**Acción:** crea los dos playbooks en la raíz de `proyecto/`:

```yaml
# proyecto/lb.yml
- name: Balanceador del portal
  hosts: lb
  become: true
  roles:
    - portal_lb
```

```yaml
# proyecto/site.yml
- name: Web
  ansible.builtin.import_playbook: web.yml
- name: Balanceador
  ansible.builtin.import_playbook: lb.yml
```

**Por qué:** cada playbook sigue sirviendo por separado, y `site.yml` es la entrada única que monta el portal
entero en el orden correcto: primero los web, después el balanceador que reparte hacia ellos.

**Resultado esperado:**

```bash
ansible-playbook -i inventories/prod/hosts.yml site.yml --list-tasks
```

```text
playbook: site.yml

  play #1 (web): Servidores web del portal	TAGS: []
    tasks:
      portal : Instalar nginx	TAGS: []
      …
      portal : Recargar nginx si ha cambiado su configuración	TAGS: []

  play #2 (lb): Balanceador del portal	TAGS: []
    tasks:
      portal_lb : Instalar nginx	TAGS: []
      portal_lb : Arrancar nginx	TAGS: []
      portal_lb : Actualizar los servidores del balanceador	TAGS: []
      portal_lb : Recargar el balanceador	TAGS: []
```

### 12 — Despliega prod entero

**Acción:**

```bash
ansible-playbook -i inventories/prod/hosts.yml site.yml
```

**Por qué:** es la prueba de que los dos roles encajan: el mismo rol `portal` de dev y pre, ahora en los dos web de
prod, y `portal_lb` delante.

**Resultado esperado:** sobre nodos vacíos, todo `changed` la primera vez:

```text
PLAY [Servidores web del portal] ***********************************************
…
PLAY [Balanceador del portal] **************************************************
…
TASK [portal_lb : Actualizar los servidores del balanceador] *******************
changed: [prod-lb1]

TASK [portal_lb : Recargar el balanceador] *************************************
changed: [prod-lb1]

PLAY RECAP *********************************************************************
prod-lb1                   : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web1                  : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Si los web ya tenían el portal, verás `changed=0` en ellos (o un cambio en `nginx.conf` de `prod-web2` si se
desplegó con el antiguo `portal.yml`, que ignoraba su `host_vars`).

> [!TIP]
> Lánzalo otra vez: los tres nodos dan `changed=0` y `Recargar el balanceador` aparece como `skipping`.

### 13 — Comprueba el reparto

**Acción:**

```bash
for i in 1 2 3 4; do curl -sI localhost:8080 | grep X-Servidor; done
```

**Por qué:** el puerto 8080 es el balanceador. Cada petición la contesta un web distinto, y `X-Servidor` dice cuál
(la IP del web y su puerto).

**Resultado esperado:** las peticiones se alternan entre `prod-web1` (172.30.0.21) y `prod-web2` (172.30.0.22):

```text
X-Servidor: 172.30.0.21:80
X-Servidor: 172.30.0.22:80
X-Servidor: 172.30.0.21:80
X-Servidor: 172.30.0.22:80
```

## Comprueba tu entendimiento

**El estado de cada web a través del balanceador**
`for i in 1 2; do curl -s localhost:8080/estado.json | grep host; done`
→ Una línea con `"host": "prod-web1"` y otra con `"host": "prod-web2"`.

**El balanceador sale del inventario**
`docker exec prod-lb1 cat /etc/nginx/sites-available/default`
→ El bloque `upstream portal` tiene `server prod-web1:80;` y `server prod-web2:80;`, los dos hosts del grupo `web`.

**Un rol, tres entornos**
`curl -s localhost:8081/estado.json`, `curl -s localhost:8082/estado.json` y `curl -s localhost:8083/estado.json`.
→ Tres entornos (`dev`, `pre`, `prod`) y tres colores distintos, con el mismo rol `portal`.

## Reto

### 1 — Un canario en prod

Tienda Norte quiere probar la 1.1.0 solo en `prod-web2`, sin tocar ningún fichero. Despliégala, comprueba a través
del balanceador que conviven las dos versiones y devuelve `prod-web2` a la versión de prod.

<details>
<summary>Ver solución</summary>

`-e` cambia la versión y `--limit` restringe el play a un nodo:

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml -e portal_version=1.1.0 --limit prod-web2
for i in 1 2 3 4; do curl -s localhost:8080/estado.json | grep -E "host|version"; done
```

```text
prod-web2                  : ok=11   changed=4    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
…
  "host": "prod-web1",
  "version": "1.0.0",
  "host": "prod-web2",
  "version": "1.1.0",
…
```

Para volver, el mismo comando sin `-e`:

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --limit prod-web2
```

```text
prod-web2                  : ok=11   changed=1    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

</details>

### 2 — ¿Y si `portal_lb` dependiera de `portal`?

En `meta/main.yml` un rol puede declarar `dependencies:` y Ansible aplica esos roles antes. Alguien propone poner
`- role: portal` como dependencia de `portal_lb` «porque los dos usan nginx». ¿Qué pasaría en `prod-lb1`?

<details>
<summary>Ver solución</summary>

El rol `portal` se aplicaría también en `prod-lb1`: le instalaría la release, activaría el sitio `portal` y
**quitaría** `sites-enabled/default`, que es justo el fichero de configuración del balanceador. `portal_lb`
escribiría después `sites-available/default`, pero ya sin enlace: el balanceador dejaría de repartir y
`curl -s localhost:8080/estado.json` contestaría con `"host": "prod-lb1"` y sin cabecera `X-Servidor`.

Una dependencia es para algo que el rol necesita de verdad para funcionar. Compartir un paquete no lo es: cada rol
instala su nginx. Si quieres aplicar un rol desde dentro de otro play o de forma condicional, la herramienta es
`ansible.builtin.include_role` (o `import_role`) en una tarea, no `dependencies`.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `X-Servidor` no aparece en `curl -sI localhost:8080` | `lb.yml` no se ha aplicado o `prod-lb1` sirve otro sitio | `ansible-playbook -i inventories/prod/hosts.yml site.yml` y comprueba `/etc/nginx/sites-available/default` en `prod-lb1` |
| `502 Bad Gateway` en el 8080 | El balanceador está, pero los web no tienen el portal | Lanza `site.yml` completo (no solo `lb.yml`) para que los web vayan antes |
| El `upstream` del balanceador sale vacío | Has lanzado `lb.yml` con un inventario sin grupo `web` (dev o pre) | El balanceador es de prod: `-i inventories/prod/hosts.yml` |
| `portal_lb` usa variables sin prefijo y ansible-lint da `var-naming[no-role-prefix]` | Variables como `backends` en vez de `portal_lb_backends` | Renómbralas con el prefijo del rol |
| Tras `-e portal_version=…` el portal se queda en esa versión | `-e` solo vale para esa ejecución, pero lo desplegado se queda | Lanza `web.yml` sin `-e` para volver a la versión del inventario |
