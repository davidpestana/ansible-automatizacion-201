# Lab — Secuencial y paralelo

[← Página anterior](01-lab-dependencias.md) · [Siguiente página →](03-lab-orquestar-nodos.md)

En el portal de Tienda Norte hay tareas que conviene hacer en todos los nodos a la vez (instalar un paquete) y otras
que deben ir de uno en uno (actualizar las web sin dejar el portal sin servicio). En este lab lanzas el mismo playbook
sobre los cuatro nodos de prod con distintos ajustes de ejecución y miras el orden en que responden: `strategy`
`linear` y `free`, `forks`, `serial` fijo y por lotes, y una tarea larga en segundo plano con `async`.

### Objetivo

Saber predecir, mirando un play, en qué orden y con qué agrupación se ejecutará en prod, y lanzar una tarea larga en
segundo plano que el play recoge al final con `ansible.builtin.async_status`.

### Punto de partida

- Terminal del Codespace. `scripts/partida.sh` se lanza desde la raíz del repositorio; lo demás, desde `proyecto/`.
- Estado: prod con las web y el balanceador instalados (el paso 1 te deja así). La base de datos no hace falta.
- Escribes dos playbooks de prueba nuevos, `ritmo.yml` y `segundo-plano.yml`. No tocas los roles.

### En qué consiste

`ritmo.yml` hace que cada nodo «trabaje» un número distinto de segundos (`prod-web2` el que menos, `prod-web1` el que
más) y luego avise de que ha terminado. Cambiando solo el modo de ejecución verás cambiar el orden de la salida y el
tiempo total que da `time`.

### 1 — Prepara el punto de partida

**Acción:**

```bash
cd "$CODESPACE_VSCODE_FOLDER"
scripts/partida.sh m09
cd proyecto
```

**Por qué:** deja `proyecto/` en el estado del módulo y prod con el portal aplicado.

**Resultado esperado:** `Listo: proyecto/ en el punto de partida «m09»` y un `PLAY RECAP` sin `failed`.

### 2 — Escribe el playbook de prueba

**Acción:** crea `proyecto/ritmo.yml`:

```yaml
# proyecto/ritmo.yml — la misma espera en los cuatro nodos de prod para ver el orden de ejecución
- name: Ritmo de ejecución en prod
  hosts: all
  gather_facts: false
  vars:
    ritmo_espera:
      prod-web1: 4
      prod-web2: 1
      prod-lb1: 2
      prod-db1: 3
  tasks:
    - name: Simular trabajo en el nodo
      ansible.builtin.command: sleep {{ ritmo_espera[inventory_hostname] }}
      changed_when: false

    - name: Avisar de que el nodo ha terminado
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} ha terminado"
```

**Por qué:** `sleep` simula una tarea lenta y distinta en cada nodo, sin cambiar nada en ellos. `gather_facts: false`
quita la recogida de facts para que solo cuente la espera.

**Resultado esperado:** el fichero guardado en `proyecto/`.

### 3 — Ejecútalo con la estrategia por defecto (`linear`)

**Acción:** `time ansible-playbook -i inventories/prod/hosts.yml ritmo.yml`

**Por qué:** es el comportamiento que has visto en todo el curso: los cuatro nodos a la vez (caben en los 5 `forks`
por defecto), pero cada tarea espera a que **todos** terminen la anterior.

**Resultado esperado:** los nodos de la primera tarea salen en el orden en que acaban (`prod-web2` primero,
`prod-web1` el último), y ninguno empieza la segunda hasta que acaba el más lento:

```text
TASK [Simular trabajo en el nodo] **********************************************
ok: [prod-web2]
ok: [prod-lb1]
ok: [prod-db1]
ok: [prod-web1]
TASK [Avisar de que el nodo ha terminado] **************************************
ok: [prod-web1] => {
    "msg": "prod-web1 ha terminado"
}
ok: [prod-lb1] => {
…
real	0m5,215s
```

El total es el del nodo más lento más un poco de conexión.

### 4 — Deja que cada nodo vaya a su ritmo (`strategy: free`)

**Acción:** `time ANSIBLE_STRATEGY=free ansible-playbook -i inventories/prod/hosts.yml ritmo.yml`

**Por qué:** `ANSIBLE_STRATEGY` cambia la estrategia por defecto sin editar el fichero; en un play se escribe
`strategy: free`. Con `free`, un nodo que acaba una tarea pasa a la siguiente sin esperar a los demás.

**Resultado esperado:** la salida ya no va agrupada por tarea; cada nodo hace sus dos tareas seguidas, en el orden en
que terminan:

```text
TASK [Simular trabajo en el nodo] **********************************************
ok: [prod-web2]
TASK [Avisar de que el nodo ha terminado] **************************************
ok: [prod-web2] => {
    "msg": "prod-web2 ha terminado"
}
TASK [Simular trabajo en el nodo] **********************************************
ok: [prod-lb1]
TASK [Avisar de que el nodo ha terminado] **************************************
ok: [prod-lb1] => {
    "msg": "prod-lb1 ha terminado"
}
…
TASK [Simular trabajo en el nodo] **********************************************
ok: [prod-web1]
…
real	0m7,581s
```

El total no baja: sigue mandando el nodo más lento. Lo que gana `free` es que los nodos rápidos terminan antes, útil
cuando las tareas no dependen unas de otras entre nodos. Para el portal es mala idea en un despliegue: una web podría
estar ya en la release nueva mientras otra sigue copiando ficheros.

### 5 — Limita las conexiones a una (`forks`)

**Acción:** `time ansible-playbook -i inventories/prod/hosts.yml ritmo.yml -f 1`

**Por qué:** `forks` (en `ansible.cfg` o con `-f`) es cuántos nodos atiende Ansible en paralelo. Con uno, cada tarea
se hace nodo a nodo, en el orden del inventario.

**Resultado esperado:** el orden de la salida es el del inventario (`prod-web1`, `prod-web2`, `prod-lb1`, `prod-db1`) y
el tiempo es la suma de todas las esperas:

```text
TASK [Simular trabajo en el nodo] **********************************************
ok: [prod-web1]
ok: [prod-web2]
ok: [prod-lb1]
ok: [prod-db1]
TASK [Avisar de que el nodo ha terminado] **************************************
…
real	0m13,532s
```

Sigue siendo `linear`: los cuatro hacen la primera tarea antes de que ninguno empiece la segunda.

### 6 — Ejecuta el play nodo a nodo (`serial: 1`)

**Acción:** en `ritmo.yml`, añade `serial: 1` bajo `gather_facts: false`:

```yaml
# proyecto/ritmo.yml (cabecera del play)
- name: Ritmo de ejecución en prod
  hosts: all
  gather_facts: false
  serial: 1
```

y ejecuta `time ansible-playbook -i inventories/prod/hosts.yml ritmo.yml`.

**Por qué:** `serial` parte los nodos en lotes y hace **el play entero** con un lote antes de pasar al siguiente. Es lo
que usa `deploy.yml` para no tocar las dos web a la vez.

**Resultado esperado:** el título del play se repite una vez por lote, y cada nodo hace sus dos tareas antes de que
empiece el siguiente:

```text
PLAY [Ritmo de ejecución en prod] **********************************************
TASK [Simular trabajo en el nodo] **********************************************
ok: [prod-web1]
TASK [Avisar de que el nodo ha terminado] **************************************
ok: [prod-web1] => {
PLAY [Ritmo de ejecución en prod] **********************************************
TASK [Simular trabajo en el nodo] **********************************************
ok: [prod-web2]
TASK [Avisar de que el nodo ha terminado] **************************************
ok: [prod-web2] => {
PLAY [Ritmo de ejecución en prod] **********************************************
…
real	0m13,469s
```

Compáralo con el paso 5: el mismo tiempo, pero agrupado por nodo en vez de por tarea.

### 7 — Lotes crecientes (`serial: [1, "50%"]`)

**Acción:** cambia la línea por `serial: [1, "50%"]` y ejecuta `time ansible-playbook -i inventories/prod/hosts.yml ritmo.yml`.

**Por qué:** un primer lote de un nodo funciona como canario; si sale bien, los siguientes lotes son de la mitad de los
nodos. Con cuatro nodos: 1, luego 2 (el 50 % de 4) y luego el que queda.

**Resultado esperado:** tres lotes:

```text
PLAY [Ritmo de ejecución en prod] **********************************************
TASK [Simular trabajo en el nodo] **********************************************
ok: [prod-web1]
…
PLAY [Ritmo de ejecución en prod] **********************************************
TASK [Simular trabajo en el nodo] **********************************************
ok: [prod-web2]
ok: [prod-lb1]
TASK [Avisar de que el nodo ha terminado] **************************************
ok: [prod-web2] => {
ok: [prod-lb1] => {
PLAY [Ritmo de ejecución en prod] **********************************************
TASK [Simular trabajo en el nodo] **********************************************
ok: [prod-db1]
…
real	0m10,551s
```

Cuando acabes, quita la línea `serial` de `ritmo.yml`.

### 8 — Lanza una tarea larga en segundo plano

**Acción:** crea `proyecto/segundo-plano.yml`:

```yaml
# proyecto/segundo-plano.yml — una tarea larga en segundo plano mientras el play sigue
- name: Copia de seguridad simulada en las web
  hosts: web
  gather_facts: false
  tasks:
    - name: Lanzar la copia en segundo plano
      ansible.builtin.command: sleep 8
      async: 60
      poll: 0
      register: copia
      changed_when: false

    - name: Comprobar el portal mientras tanto
      ansible.builtin.uri:
        url: http://localhost/estado.json
      register: copia_portal

    - name: Mostrar la versión servida
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }} sirve {{ copia_portal.json.version }} durante la copia"

    - name: Esperar a que termine la copia
      ansible.builtin.async_status:
        jid: "{{ copia.ansible_job_id }}"
      register: copia_estado
      until: copia_estado.finished
      retries: 10
      delay: 2
```

y ejecútalo: `time ansible-playbook -i inventories/prod/hosts.yml segundo-plano.yml`

**Por qué:** `async: 60` deja la tarea corriendo en el nodo con un límite de 60 y `poll: 0` hace que Ansible
no se quede esperando. Mientras la «copia» sigue, el play comprueba el portal. `ansible.builtin.async_status`, con el
identificador que guardó `register`, recoge el resultado y repite hasta que `finished` es verdadero.

**Resultado esperado:** la comprobación del portal sale antes de que acabe la copia, y la última tarea reintenta
hasta que termina:

```text
TASK [Lanzar la copia en segundo plano] ****************************************
ok: [prod-web1]
ok: [prod-web2]
TASK [Comprobar el portal mientras tanto] **************************************
ok: [prod-web2]
ok: [prod-web1]
TASK [Mostrar la versión servida] **********************************************
ok: [prod-web1] => {
    "msg": "prod-web1 sirve 1.0.0 durante la copia"
}
…
TASK [Esperar a que termine la copia] ******************************************
FAILED - RETRYING: [prod-web2]: Esperar a que termine la copia (10 retries left).
FAILED - RETRYING: [prod-web1]: Esperar a que termine la copia (10 retries left).
…
FAILED - RETRYING: [prod-web2]: Esperar a que termine la copia (7 retries left).
changed: [prod-web1]
changed: [prod-web2]
PLAY RECAP *********************************************************************
prod-web1                  : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
prod-web2                  : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
real	0m12,568s
```

Los `FAILED - RETRYING` no son errores: son las consultas de `until` mientras la tarea sigue en marcha. El `changed=1`
lo pone `async_status` al recoger el trabajo.

## Comprueba tu entendimiento

**Predice antes de ejecutar**
Con `serial: 2` en `ritmo.yml`, ¿cuántas veces sale `PLAY [Ritmo de ejecución en prod]` y qué nodos van juntos?
Ejecútalo para confirmarlo.
→ Dos veces: primero `prod-web1` y `prod-web2`, después `prod-lb1` y `prod-db1` (los lotes siguen el orden del
inventario; dentro de un lote, `prod-web2` sale antes porque espera menos).

**`forks` dentro de un lote**
Con `serial: 2` y `-f 1`, ejecuta `ritmo.yml`.
→ Sigue habiendo dos lotes de dos nodos, pero dentro del primero sale `ok: [prod-web1]` antes que `ok: [prod-web2]`:
con un solo fork, los nodos del lote se atienden por orden de inventario y no por orden de llegada.

**`serial` no es `free`**
Vuelve a ejecutar `ritmo.yml` sin `serial` y con `ANSIBLE_STRATEGY=free`.
→ Un solo `PLAY [...]` y las tareas de cada nodo intercaladas; con `serial` el título del play se repite por lote.

## Reto

### 1 — El despliegue en lotes

`deploy.yml` usa `serial: 1` sobre el grupo `web`. Imagina que prod crece a diez web. ¿Qué valor de `serial` usarías
para hacer primero un canario, después dos web y después el resto en lotes de la mitad, y qué haría
`max_fail_percentage: 0` si falla el canario?

<details>
<summary>Ver solución</summary>

`serial: [1, 2, "50%"]`. El último valor se repite hasta acabar con los nodos. Con `max_fail_percentage: 0`, un fallo
en el lote del canario detiene el play: los lotes siguientes no empiezan y el resto de web siguen con la release
anterior.

</details>

### 2 — Sin esperar el resultado

¿Qué pasa si en `segundo-plano.yml` quitas la última tarea? ¿Se corta la copia al terminar el playbook?

<details>
<summary>Ver solución</summary>

No: la tarea sigue en el nodo hasta que acaba o hasta que se cumple el límite de `async` (60). El playbook termina
antes y nadie comprueba si la copia salió bien. Por eso, con `poll: 0`, se recoge el resultado con
`ansible.builtin.async_status` antes de dar el trabajo por bueno.

</details>

## Errores frecuentes

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `object of type 'dict' has no attribute 'dev-web1'` | Lanzaste `ritmo.yml` sin `-i inventories/prod/hosts.yml`: el inventario de dev tiene nodos que no están en `ritmo_espera` | Ejecuta con el inventario de prod |
| Con `strategy: free` no ves diferencia | Todas las esperas son iguales o solo hay una tarea | Usa los valores distintos de `ritmo_espera` y las dos tareas |
| `async_status` falla diciendo que no encuentra el trabajo | El trabajo se lanzó con otro usuario (`become` en una tarea y no en la otra) | Usa `{{ copia.ansible_job_id }}` registrado en la misma tarea y el mismo `become` en las dos |
| `FAILED! … attempts` en la última tarea | La tarea larga dura más que `retries` × `delay` | Sube `retries` o `delay`, o baja la duración de la tarea |
