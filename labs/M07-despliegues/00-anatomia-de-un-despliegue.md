# Anatomía de un despliegue

[← Página anterior](README.md) · [Siguiente página →](01-lab-despliegue-completo.md)

Tienda Norte tiene el portal 1.0.0 en prod y el equipo de producto ha entregado la 1.1.0, con seguimiento de
pedidos. Esta demostración abre un despliegue por dentro, sobre `prod-web1` y `prod-web2`: dónde queda cada
release, qué hace el enlace `current`, qué publica `estado.json` y por qué hace falta verificar el portal
después de desplegar, aunque Ansible diga que todo ha ido bien.

## Punto de partida

- Terminal del Codespace, en la raíz del repo. El estado se prepara con:

  ```bash
  # Terminal del Codespace, en la raíz del repo
  cd "$CODESPACE_VSCODE_FOLDER"
  scripts/partida.sh m07-00
  cd proyecto
  ```

- Estado: `proyecto/` con los roles `portal` y `portal_lb` (handlers y tags `paquetes`, `config`, `despliegue`) y
  los nodos de prod con el portal 1.0.0 instalado por `site.yml`. El script borra antes las releases que hubiera
  de pruebas anteriores, así que solo existe la 1.0.0.
- Todo lo que sigue se lanza desde `proyecto/`.

## Recorrido

1. El despliegue de una release son las cuatro tareas de `roles/portal/tasks/desplegar.yml`, que `main.yml`
   importa con el tag `despliegue`:

   ```yaml
   # proyecto/roles/portal/tasks/desplegar.yml
   - name: Crear la carpeta de la release
     ansible.builtin.file:
       path: "{{ portal_raiz }}/releases/{{ portal_version }}"
       state: directory
       mode: "0755"

   - name: Copiar la release {{ portal_version }}
     ansible.builtin.copy:
       src: "{{ playbook_dir }}/app/releases/{{ portal_version }}/"
       dest: "{{ portal_raiz }}/releases/{{ portal_version }}/"
       mode: "0644"

   - name: Apuntar current a la release {{ portal_version }}
     ansible.builtin.file:
       src: "{{ portal_raiz }}/releases/{{ portal_version }}"
       dest: "{{ portal_raiz }}/current"
       state: link

   - name: Publicar el estado del nodo
     ansible.builtin.template:
       src: estado.json.j2
       dest: "{{ portal_raiz }}/releases/{{ portal_version }}/estado.json"
       mode: "0644"
   ```

   La versión no está escrita en ninguna tarea: sale de `portal_version`, que en prod vale `1.0.0`
   (`inventories/prod/group_vars/all.yml`). Cambiar de release es cambiar esa variable.

2. En `prod-web1`, la release instalada es una carpeta con su `index.html` y su `estado.json`, y `current`
   apunta a ella. nginx sirve siempre `/srv/portal/current` (`root` en `portal.conf.j2`):

   ```bash
   # Terminal del Codespace, en proyecto/
   ssh -F ../infra/ssh_config prod-web1 ls -l /srv/portal /srv/portal/releases/1.0.0
   ```

   ```text
   /srv/portal:
   total 4
   lrwxrwxrwx 1 root root   26 Oct 26 19:29 current -> /srv/portal/releases/1.0.0
   drwxr-xr-x 3 root root 4096 Oct 26 19:29 releases

   /srv/portal/releases/1.0.0:
   total 8
   -rw-r--r-- 1 root root 103 Oct 26 19:29 estado.json
   -rw-r--r-- 1 root root 706 Oct 26 19:29 index.html
   ```

3. La 1.1.0 se despliega en los dos web pasando la versión con `-e` y ejecutando solo las tareas con el tag
   `despliegue`; nginx, su configuración y el balanceador no se tocan:

   ```bash
   # Terminal del Codespace, en proyecto/
   ansible-playbook -i inventories/prod/hosts.yml web.yml --tags despliegue -e portal_version=1.1.0
   ```

   ```text
   PLAY [Servidores web del portal] ***********************************************

   TASK [Gathering Facts] *********************************************************
   ok: [prod-web1]
   ok: [prod-web2]

   TASK [portal : Crear la carpeta de la release] *********************************
   changed: [prod-web1]
   changed: [prod-web2]

   TASK [portal : Copiar la release 1.1.0] ****************************************
   changed: [prod-web2]
   changed: [prod-web1]

   TASK [portal : Apuntar current a la release 1.1.0] *****************************
   changed: [prod-web2]
   changed: [prod-web1]

   TASK [portal : Publicar el estado del nodo] ************************************
   changed: [prod-web1]
   changed: [prod-web2]

   PLAY RECAP *********************************************************************
   prod-web1                  : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
   prod-web2                  : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
   ```

   `-e` tiene más prioridad que `group_vars`, así que manda sobre el `1.0.0` del inventario solo en esta ejecución.
   No hay recarga de nginx: el `root` sigue siendo `/srv/portal/current` y nginx resuelve el enlace en cada petición.

4. En el nodo conviven ahora las dos releases y `current` ha cambiado de destino. La 1.0.0 sigue intacta,
   con su propio `estado.json`:

   ```bash
   # Terminal del Codespace, en proyecto/
   ssh -F ../infra/ssh_config prod-web1 ls -l /srv/portal /srv/portal/releases
   ssh -F ../infra/ssh_config prod-web1 cat /srv/portal/releases/1.0.0/estado.json /srv/portal/current/estado.json
   ```

   ```text
   /srv/portal:
   total 4
   lrwxrwxrwx 1 root root   26 Oct 26 19:30 current -> /srv/portal/releases/1.1.0
   drwxr-xr-x 4 root root 4096 Oct 26 19:30 releases

   /srv/portal/releases:
   total 8
   drwxr-xr-x 2 root root 4096 Oct 26 19:29 1.0.0
   drwxr-xr-x 2 root root 4096 Oct 26 19:30 1.1.0
   ```

   ```text
   {
     "host": "prod-web1",
     "entorno": "prod",
     "version": "1.0.0",
     "color": "#15803d",
     "db": ""
   }
   {
     "host": "prod-web1",
     "entorno": "prod",
     "version": "1.1.0",
     "color": "#15803d",
     "db": ""
   }
   ```

   Que `estado.json` viva dentro de cada release es lo que hace fiable la comprobación: si `current` vuelve a la
   1.0.0, el nodo vuelve a decir `"version": "1.0.0"` sin tocar nada más.

5. La verificación tras desplegar la hace el módulo `ansible.builtin.uri` desde cada nodo: pide `http://localhost/`
   y falla si la respuesta no es 200. Con la 1.1.0, los dos web responden:

   ```bash
   # Terminal del Codespace, en proyecto/
   ansible -i inventories/prod/hosts.yml web -m ansible.builtin.uri -a "url=http://localhost/"
   ```

   ```text
   prod-web2 | SUCCESS => {
       …
       "msg": "OK (716 bytes)",
       "redirected": false,
       "server": "nginx/1.26.3",
       "status": 200,
       "url": "http://localhost/"
   }
   prod-web1 | SUCCESS => {
       …
       "status": 200,
       "url": "http://localhost/"
   }
   ```

6. La release 1.2.0 se empaquetó sin `index.html` (en `app/releases/1.2.0/` solo hay un `LEEME.txt`). Desplegada
   solo en `prod-web1` con `--limit`, Ansible no ve ningún problema:

   ```bash
   # Terminal del Codespace, en proyecto/
   ansible-playbook -i inventories/prod/hosts.yml web.yml --tags despliegue -e portal_version=1.2.0 --limit prod-web1
   ```

   ```text
   TASK [portal : Apuntar current a la release 1.2.0] *****************************
   changed: [prod-web1]

   TASK [portal : Publicar el estado del nodo] ************************************
   changed: [prod-web1]

   PLAY RECAP *********************************************************************
   prod-web1                  : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
   ```

   El portal, en cambio, ya no sirve la página, aunque `estado.json` dice `1.2.0`. La misma comprobación con `uri`
   lo detecta:

   ```bash
   # Terminal del Codespace, en proyecto/
   curl -sI localhost:8083 | head -1
   ansible -i inventories/prod/hosts.yml prod-web1 -m ansible.builtin.uri -a "url=http://localhost/"
   ```

   ```text
   HTTP/1.1 403 Forbidden
   ```

   ```text
   [ERROR]: Task failed: Module failed: Status code was 403 and not [200]: HTTP Error 403: Forbidden
   …
   prod-web1 | FAILED! => {
       …
       "msg": "Status code was 403 and not [200]: HTTP Error 403: Forbidden",
       "status": 403,
       "url": "http://localhost/"
   }
   ```

   `failed=0` en el playbook y 403 en el portal: un despliegue que no verifica deja prod roto sin enterarse.

7. Volver a la release buena es desplegar otra vez la 1.1.0. La carpeta ya existe, así que lo único que cambia
   es el enlace:

   ```bash
   # Terminal del Codespace, en proyecto/
   ansible-playbook -i inventories/prod/hosts.yml web.yml --tags despliegue -e portal_version=1.1.0 --limit prod-web1
   curl -sI localhost:8083 | head -1
   ```

   ```text
   TASK [portal : Crear la carpeta de la release] *********************************
   ok: [prod-web1]

   TASK [portal : Copiar la release 1.1.0] ****************************************
   ok: [prod-web1]

   TASK [portal : Apuntar current a la release 1.1.0] *****************************
   changed: [prod-web1]

   TASK [portal : Publicar el estado del nodo] ************************************
   ok: [prod-web1]

   PLAY RECAP *********************************************************************
   prod-web1                  : ok=5    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
   ```

   ```text
   HTTP/1.1 200 OK
   ```

   `changed=1`: la vuelta atrás es un solo cambio, el de `current`.

## Qué queda visto

- Una release es una carpeta en `/srv/portal/releases/<versión>` y `current` decide cuál sirve nginx; cambiar de
  versión, hacia delante o hacia atrás, es mover ese enlace.
- `estado.json`, dentro de cada release, dice qué versión responde de verdad en cada nodo.
- `-e portal_version=…` elige la versión de una ejecución y `--tags despliegue` limita el trabajo a la publicación.
- Las tareas en verde no garantizan que el portal funcione: hace falta verificarlo con `uri` o `curl`.

Se practica en [Lab — Despliegue completo](01-lab-despliegue-completo.md), con el balanceador delante, y la
verificación con vuelta atrás automática en [Lab — Despliegue escalonado](03-lab-despliegue-escalonado.md).
Los dos labs se hacen sin haber seguido esta demostración.
