# De dónde sale cada valor

[← Página anterior](README.md) · [Siguiente página →](01-lab-group-vars-host-vars.md)

El portal de Tienda Norte tiene que salir verde en prod, ámbar en pre y azul en dev, y algún nodo necesita
un ajuste propio. Esta demostración define la misma variable, `portal_color`, en varios sitios del proyecto y,
después de cada cambio, consulta qué valor recibe cada nodo de prod.

## Qué se va a ver

**Qué se hace**

1. Se parte de un `portal.yml` con la versión y el color escritos a mano.
2. Se define `portal_color` en el inventario, en `group_vars/all.yml`, en `group_vars/web.yml` y en `host_vars/prod-web2.yml`, comprobando el valor de cada nodo tras cada paso.
3. Se impone un valor con `-e` en la línea de comandos.
4. Se define la variable en las `vars:` del play.

**Objetivos**

- Conocer los sitios donde puede vivir una variable.
- Saber cuál gana cuando la misma variable está en varios.
- Consultar el valor que recibe cada nodo sin cambiar nada.

**Conclusiones**

- Gana el sitio más concreto: el nodo a su grupo, y un grupo a `all`.
- Las `vars:` del play y `-e` se imponen a todo lo que viene del inventario.

## Punto de partida

- Terminal del Codespace, en la raíz del repositorio:

  ```bash
  cd "$CODESPACE_VSCODE_FOLDER"
  scripts/partida.sh m04
  cd proyecto
  ```

- Estado: `proyecto/` con `ansible.cfg`, los inventarios `inventories/{dev,pre,prod}/hosts.yml` (cada uno con
  `vars: portal_entorno`) y el `portal.yml` del módulo anterior, con los valores escritos dentro.
- Nodos: basta con que respondan por SSH (`scripts/nodos.sh estado`). Nada de lo que se hace aquí los cambia:
  `debug` y `ansible-inventory` se resuelven en el nodo de control.

## Recorrido

1. El problema de partida está en `portal.yml`: la versión y el color están escritos a mano.

   ```bash
   grep -n -e 1.0.0 -e 2563eb portal.yml
   ```

   ```text
   32:        path: /srv/portal/releases/1.0.0
   36:    - name: Copiar la release 1.0.0
   38:        src: app/releases/1.0.0/
   39:        dest: /srv/portal/releases/1.0.0/
   42:    - name: Apuntar current a la release 1.0.0
   44:        src: /srv/portal/releases/1.0.0
   52:          {"host": "{{ inventory_hostname }}", "entorno": "{{ portal_entorno }}", "version": "1.0.0", "color": "#2563eb", "db": ""}
   ```

   Lo único que ya es variable es `portal_entorno`, que viene del inventario. Su valor para un nodo se
   consulta con `ansible-inventory --host`:

   ```bash
   ansible-inventory -i inventories/prod/hosts.yml --host prod-web1
   ```

   ```text
   {
       "portal_entorno": "prod"
   }
   ```

2. **Primer sitio: el propio inventario.** En `inventories/prod/hosts.yml` se añade `portal_color` junto a
   `portal_entorno`. Para que el origen se reconozca a simple vista, el valor dice de dónde viene en lugar de
   ser un color:

   ```yaml
   # inventories/prod/hosts.yml (final del fichero)
     vars:
       portal_entorno: prod
       portal_color: desde-hosts.yml
   ```

   Con `ansible.builtin.debug` y `var=` se ve el valor que recibe cada nodo:

   ```bash
   ansible all -i inventories/prod/hosts.yml -m ansible.builtin.debug -a var=portal_color
   ```

   ```text
   prod-web1 | SUCCESS => {
       "portal_color": "desde-hosts.yml"
   }
   prod-lb1 | SUCCESS => {
       "portal_color": "desde-hosts.yml"
   }
   prod-web2 | SUCCESS => {
       "portal_color": "desde-hosts.yml"
   }
   prod-db1 | SUCCESS => {
       "portal_color": "desde-hosts.yml"
   }
   ```

   Los cuatro nodos lo heredan porque está en el grupo `all`. El orden de las líneas cambia de una ejecución
   a otra: los nodos responden en paralelo.

3. **Segundo sitio: `group_vars/all.yml`.** Junto al inventario se crea la carpeta `group_vars` con un fichero
   para el grupo `all`:

   ```yaml
   # inventories/prod/group_vars/all.yml
   portal_color: desde-group_vars-all
   ```

   ```bash
   ansible all -i inventories/prod/hosts.yml -m ansible.builtin.debug -a var=portal_color
   ```

   ```text
   prod-web1 | SUCCESS => {
       "portal_color": "desde-group_vars-all"
   }
   prod-web2 | SUCCESS => {
       "portal_color": "desde-group_vars-all"
   }
   prod-lb1 | SUCCESS => {
       "portal_color": "desde-group_vars-all"
   }
   prod-db1 | SUCCESS => {
       "portal_color": "desde-group_vars-all"
   }
   ```

   Para el mismo grupo, el fichero de `group_vars/` gana a lo escrito en `hosts.yml`.

4. **Tercer sitio: `group_vars/web.yml`.** Un fichero con el nombre de un grupo solo afecta a sus nodos:

   ```yaml
   # inventories/prod/group_vars/web.yml
   portal_color: desde-group_vars-web
   ```

   ```bash
   ansible all -i inventories/prod/hosts.yml -m ansible.builtin.debug -a var=portal_color
   ```

   ```text
   prod-db1 | SUCCESS => {
       "portal_color": "desde-group_vars-all"
   }
   prod-web1 | SUCCESS => {
       "portal_color": "desde-group_vars-web"
   }
   prod-web2 | SUCCESS => {
       "portal_color": "desde-group_vars-web"
   }
   prod-lb1 | SUCCESS => {
       "portal_color": "desde-group_vars-all"
   }
   ```

   Las dos web cambian; el balanceador y la base de datos siguen con el valor de `all`. `web` es hijo de
   `all`, y el grupo más concreto gana.

5. **Cuarto sitio: `host_vars/prod-web2.yml`.** Un fichero con el nombre de un nodo es la excepción de ese
   nodo:

   ```yaml
   # inventories/prod/host_vars/prod-web2.yml
   portal_color: desde-host_vars-prod-web2
   ```

   ```bash
   ansible all -i inventories/prod/hosts.yml -m ansible.builtin.debug -a var=portal_color
   ```

   ```text
   prod-lb1 | SUCCESS => {
       "portal_color": "desde-group_vars-all"
   }
   prod-web1 | SUCCESS => {
       "portal_color": "desde-group_vars-web"
   }
   prod-web2 | SUCCESS => {
       "portal_color": "desde-host_vars-prod-web2"
   }
   prod-db1 | SUCCESS => {
       "portal_color": "desde-group_vars-all"
   }
   ```

   La carpeta del inventario de prod queda así:

   ```text
   inventories/prod
   ├── group_vars
   │   ├── all.yml
   │   └── web.yml
   ├── hosts.yml
   └── host_vars
       └── prod-web2.yml
   ```

   `ansible-inventory --host` muestra el resultado de mezclar todo eso para un nodo, sin conectarse a él:

   ```bash
   ansible-inventory -i inventories/prod/hosts.yml --host prod-web2
   ```

   ```text
   {
       "portal_color": "desde-host_vars-prod-web2",
       "portal_entorno": "prod"
   }
   ```

6. **Quinto sitio: la línea de comandos.** Con `-e` el valor se impone a todo lo anterior, en todos los nodos:

   ```bash
   ansible web -i inventories/prod/hosts.yml -m ansible.builtin.debug -a var=portal_color -e portal_color=desde-la-linea-de-comandos
   ```

   ```text
   prod-web1 | SUCCESS => {
       "portal_color": "desde-la-linea-de-comandos"
   }
   prod-web2 | SUCCESS => {
       "portal_color": "desde-la-linea-de-comandos"
   }
   ```

7. **Un sitio más: las `vars:` del play.** El inventario no sabe nada de los playbooks, así que esto no sale en
   `ansible-inventory`. Un playbook mínimo, `ver-color.yml`, define el color en su bloque `vars:`:

   ```yaml
   # ver-color.yml
   - name: Ver de dónde sale el color
     hosts: web
     gather_facts: false
     vars:
       portal_color: desde-vars-del-play
     tasks:
       - name: Mostrar portal_color
         ansible.builtin.debug:
           var: portal_color
   ```

   ```bash
   ansible-playbook -i inventories/prod/hosts.yml ver-color.yml
   ```

   ```text
   TASK [Mostrar portal_color] ****************************************************
   ok: [prod-web1] => {
       "portal_color": "desde-vars-del-play"
   }
   ok: [prod-web2] => {
       "portal_color": "desde-vars-del-play"
   }
   ```

   Hasta `prod-web2`, que tiene su `host_vars`, recibe el valor del play. Solo `-e` lo supera:

   ```bash
   ansible-playbook -i inventories/prod/hosts.yml ver-color.yml -e portal_color=desde-la-linea-de-comandos
   ```

   ```text
   TASK [Mostrar portal_color] ****************************************************
   ok: [prod-web1] => {
       "portal_color": "desde-la-linea-de-comandos"
   }
   ok: [prod-web2] => {
       "portal_color": "desde-la-linea-de-comandos"
   }
   ```

8. Ordenado de menos a más, lo que se ha visto con `portal_color`:

   | Sitio | Afecta a | En esta demo lo recibe |
   |-------|----------|------------------------|
   | `vars:` de `all` en `hosts.yml` | Todo el entorno | Nadie, en cuanto existe `group_vars/all.yml` |
   | `group_vars/all.yml` | Todo el entorno | `prod-lb1`, `prod-db1` |
   | `group_vars/web.yml` | Los nodos del grupo `web` | `prod-web1` |
   | `host_vars/prod-web2.yml` | Un nodo | `prod-web2` |
   | `vars:` del play | Los nodos del play | Todos los del play, por encima del inventario |
   | `-e` | Toda la ejecución | Todos, siempre |

   Para volver al punto de partida sin estos ficheros de prueba, basta con `scripts/partida.sh m04` desde la
   raíz del repositorio.

## Qué queda visto

La misma variable puede venir del inventario, de `group_vars/all.yml`, de un `group_vars/<grupo>.yml`, de
`host_vars/<nodo>.yml`, del play o de `-e`, y gana el sitio más concreto, con el play y `-e` por encima del
inventario. `ansible-inventory --host` y `ansible … -m ansible.builtin.debug -a var=…` dicen qué valor recibe
cada nodo sin cambiar nada. En [Lab — group_vars y host_vars](01-lab-group-vars-host-vars.md) los valores
reales del portal se llevan a esos ficheros; el lab se puede hacer sin haber seguido esta demostración.
