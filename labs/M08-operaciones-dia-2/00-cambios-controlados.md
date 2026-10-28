# Cambios controlados

[← Página anterior](README.md) · [Siguiente página →](01-lab-parcheo.md)

Seguridad de Tienda Norte ha pasado una auditoría al portal de pedidos y ha abierto una petición: los servidores
web de producción anuncian la versión exacta de nginx en la cabecera `Server`, y eso le da pistas a un atacante.
Hay que ocultarla con `server_tokens off`. Esta demostración sigue el cambio de principio a fin, tal como se lleva
a producción: se simula, se aplica en un nodo, se comprueba, se extiende al resto y se deja preparada la vuelta atrás.

## Punto de partida

- Terminal del Codespace, en la raíz del repositorio:

  ```bash
  scripts/partida.sh m08
  cd proyecto
  ```

- Estado: `proyecto/` con los roles `portal` y `portal_lb`, `site.yml`, `web.yml`, `lb.yml` y `deploy.yml`.
  `partida.sh` aplica `site.yml` en prod: `prod-lb1` reparte entre `prod-web1` y `prod-web2`, los dos con la
  release 1.0.0.
- Todo `ansible-playbook` se lanza desde `proyecto/`.

## Recorrido

### 1 — La situación de partida

Antes de tocar nada se mira cómo están los dos servidores web, cada uno en su puerto:

```bash
curl -sI localhost:8083 | grep Server
curl -sI localhost:8084 | grep Server
```

```text
Server: nginx/1.26.3
Server: nginx/1.26.3
```

Es lo que ha visto la auditoría. El balanceador (`localhost:8080`) ya responde `Server: nginx`, sin versión, porque
el `nginx.conf` que trae Debian lo tiene así. El rol `portal`, en cambio, escribe su propio `nginx.conf` y no lo
incluye.

### 2 — El cambio en el rol, con copia de seguridad

El cambio no se hace en los nodos, sino en la plantilla del rol. En `roles/portal/templates/nginx.conf.j2` se
añade una línea al bloque `http`:

```jinja
# proyecto/roles/portal/templates/nginx.conf.j2 (fragmento)
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    server_tokens off;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    include /etc/nginx/sites-enabled/*;
}
```

Y en la tarea que la aplica, en `roles/portal/tasks/main.yml`, se añade `backup: true`:

```yaml
# proyecto/roles/portal/tasks/main.yml (fragmento)
- name: Configurar nginx (nginx.conf)
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    mode: "0644"
    validate: nginx -t -c %s
    backup: true
  notify: Recargar nginx
  tags: [config]
```

Con `backup: true`, cada vez que la tarea sustituye el fichero deja el anterior al lado, con la fecha en el nombre.
Es la vuelta atrás más rápida: está en el propio nodo y no depende de nadie. `ansible.builtin.copy` admite la misma
opción.

### 3 — Simular contra producción

Con el cambio en el proyecto, el primer contacto con prod es una simulación:

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --check --diff
```

```text
TASK [portal : Configurar nginx (nginx.conf)] **********************************
--- before: /etc/nginx/nginx.conf
+++ after: …/nginx.conf.j2
@@ -12,6 +12,7 @@
     include /etc/nginx/mime.types;
     default_type application/octet-stream;
     sendfile on;
+    server_tokens off;
     access_log /var/log/nginx/access.log;
     error_log /var/log/nginx/error.log;
     include /etc/nginx/sites-enabled/*;

changed: [prod-web1]
…
changed: [prod-web2]
…
RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [prod-web2]
changed: [prod-web1]

PLAY RECAP *********************************************************************
prod-web1                  : ok=12   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`--check` no cambia nada en los nodos; `--diff` enseña la línea exacta que entraría. Es lo que se espera de la
petición: una línea nueva en `nginx.conf` y una recarga de nginx en cada web. El resto de tareas (release, sitio,
enlace `current`) sale `ok`. Un `changed` en cualquier otra tarea sería una señal para parar y averiguar por qué
antes de aplicar.

### 4 — Aplicar en el canario

El cambio se aplica primero en un solo nodo, `prod-web1`, el canario:

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml --limit prod-web1
```

```text
TASK [portal : Configurar nginx (nginx.conf)] **********************************
changed: [prod-web1]
…
RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [prod-web1]

PLAY RECAP *********************************************************************
prod-web1                  : ok=12   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`--limit` restringe la ejecución a los nodos indicados aunque el play diga `hosts: web`. Si algo sale mal, solo
lo sufre `prod-web1`, y el balanceador sigue teniendo a `prod-web2` sano.

### 5 — Comprobar el canario

Ahora los dos servidores web responden distinto:

```bash
curl -sI localhost:8083 | grep Server
curl -sI localhost:8084 | grep Server
```

```text
Server: nginx
Server: nginx/1.26.3
```

El canario ya no anuncia la versión; `prod-web2` sigue como estaba. El balanceador sigue repartiendo entre los dos,
como muestra su cabecera `X-Servidor` en dos peticiones seguidas:

```bash
for i in 1 2; do curl -sI localhost:8080 | grep X-Servidor; done
```

```text
X-Servidor: 172.30.0.21:80
X-Servidor: 172.30.0.22:80
```

La copia de seguridad está junto al fichero nuevo:

```bash
docker exec prod-web1 ls /etc/nginx
```

```text
conf.d
…
nginx.conf
nginx.conf.1040.2026-10-26@19:29:42~
…
```

Y lo que cambia entre la copia y el fichero actual es justo la línea de la petición:

```bash
docker exec prod-web1 sh -c 'diff /etc/nginx/nginx.conf.*~ /etc/nginx/nginx.conf'
```

```text
14a15
>     server_tokens off;
```

El número y la fecha del nombre cambian en cada ejecución. Si el canario hubiera ido mal, volver atrás en el nodo
sería copiar ese fichero sobre `nginx.conf` y recargar nginx; y en el proyecto, deshacer el cambio de la plantilla.

### 6 — Extender al resto

Con el canario bien, se lanza el mismo playbook sin `--limit`:

```bash
ansible-playbook -i inventories/prod/hosts.yml web.yml
```

```text
TASK [portal : Configurar nginx (nginx.conf)] **********************************
changed: [prod-web2]
ok: [prod-web1]
…
RUNNING HANDLER [portal : Recargar nginx] **************************************
changed: [prod-web2]

PLAY RECAP *********************************************************************
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=12   changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`prod-web1` ya estaba bien y sale `changed=0`: gracias a la idempotencia se puede repetir el playbook entero sin
miedo a tocar dos veces el canario. Solo `prod-web2` cambia y se recarga.

### 7 — Cerrar el cambio

Para cerrar se repite la comprobación de la petición y una simulación más:

```bash
curl -sI localhost:8084 | grep Server
ansible-playbook -i inventories/prod/hosts.yml web.yml --check --diff
```

```text
Server: nginx
…
PLAY RECAP *********************************************************************
prod-web1                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=11   changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Si el check no encuentra cambios después de aplicar, prod coincide con el proyecto: el cambio está entero y no
queda nada a medias.

## Qué queda visto

- Un cambio en prod empieza en el proyecto (plantilla y tarea del rol), no en el nodo.
- `--check --diff` enseña qué tareas y qué líneas cambiarían, sin tocar nada.
- `--limit prod-web1` convierte un nodo en canario; el resto se aplica después con el mismo playbook.
- `backup: true` deja en el nodo el fichero anterior para volver atrás deprisa.
- Un check con `changed=0` al final confirma que prod ha quedado como dice el proyecto.

El mismo ciclo, con un valor que el check no reconoce como peligroso, se practica en el
[Lab — Cambio en producción](02-lab-cambio-en-produccion.md). Se puede hacer sin haber seguido esta demostración.
