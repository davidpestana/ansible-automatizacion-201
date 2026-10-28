# Entorno del curso

Todo corre en tu Codespace. Nada se instala en tu equipo.

| Pieza | Dónde | Qué es |
|-------|-------|--------|
| Nodo de control | El propio Codespace | `ansible`, `ansible-lint`, `make`, `git`, `gh` (de `requirements.txt` y del devcontainer) |
| Nodos gestionados | Contenedores Debian 13 con SSH (`infra/compose.yaml`) | Los servidores del portal de Tienda Norte |
| Proyecto Ansible | `proyecto/` | Donde trabajas en cada laboratorio |
| Puntos de partida | `partidas/<estado>/` | El proyecto tal como queda al empezar cada módulo o página |

## Los nodos del portal

| Nodo | Entorno | Papel | IP | Portal en el navegador |
|------|---------|-------|----|------------------------|
| `dev-web1` | dev | web | 172.30.0.11 | puerto 8081 |
| `pre-web1` | pre | web | 172.30.0.12 | puerto 8082 |
| `prod-lb1` | prod | balanceador | 172.30.0.20 | puerto 8080 |
| `prod-web1` | prod | web | 172.30.0.21 | puerto 8083 |
| `prod-web2` | prod | web | 172.30.0.22 | puerto 8084 |
| `prod-db1` | prod | PostgreSQL | 172.30.0.30 | — |

Cada nodo tiene SSH, Python 3 y un usuario `ansible` con `sudo` sin contraseña. **No** tiene ningún agente
de Ansible: es justo lo que se aprovecha en el curso.

Ansible llega a ellos por SSH con la clave del curso (`~/.ssh/curso-ansible/curso_ansible`, la crea
`scripts/nodos.sh` la primera vez). Los nombres se resuelven con `infra/ssh_config`, que `proyecto/ansible.cfg`
pasa a SSH. Para entrar a mano en un nodo, desde `proyecto/`:

```bash
ssh -F ../infra/ssh_config prod-web1
```

## Comandos

Desde la raíz del repositorio:

| Comando | Qué hace |
|---------|----------|
| `scripts/nodos.sh up` | Levanta los seis nodos (se lanza solo al arrancar el Codespace) |
| `scripts/nodos.sh estado` | Comprueba el SSH de cada nodo |
| `scripts/nodos.sh reset` | Borra los nodos y los crea limpios, sin nginx ni portal |
| `scripts/partida.sh <estado>` | Deja `proyecto/` en un punto de partida (lo anterior queda en `proyecto.anterior/`) |
| `scripts/partida.sh <estado> --limpio` | Lo mismo, con los nodos recién creados |

Los puertos 8080–8084 se abren en la pestaña **Puertos** del Codespace; desde el terminal, `curl localhost:8080`.

## Demo de AWX (M11)

`scripts/awx-up.sh` crea un clúster kind de un nodo, instala AWX Operator 2.19.1 y una instancia de AWX
24.6.1 en `http://localhost:8043`. El Codespace normal (2 núcleos, 8 GB) no basta: AWX se levanta en un
Codespace creado con la configuración **Ansible — Tienda Norte + AWX (demo M11)** (`.devcontainer/awx/`, 4 núcleos
y 16 GB, con kind y kubectl). En GitHub: **Code** → **Codespaces** → **…** → **New with options…** y elige esa
configuración. Tarda varios minutos. `scripts/awx-down.sh` lo borra.

## Solución de problemas

| Síntoma | Causa probable | Cómo arreglarlo |
|---------|----------------|-----------------|
| `UNREACHABLE! … Connection timed out` en todos los nodos | Los nodos no están levantados (Codespace recién reanudado) | `scripts/nodos.sh up` |
| `Permission denied (publickey)` | La clave del curso no coincide con la de los nodos (se borró `~/.ssh/curso-ansible`) | `scripts/nodos.sh up`; si sigue, `scripts/nodos.sh reset` |
| `[WARNING]: Ansible is being run in a world writable directory …, ignoring it as an ansible.cfg source` | La carpeta tiene permiso de escritura para todos y Ansible no lee su `ansible.cfg` | `chmod -R o-w proyecto` desde la raíz del repositorio |
| `apt` falla dentro de un nodo con `Temporary failure resolving` o se queda colgado, pero `curl` desde el terminal del Codespace sí funciona | Red de Docker en Codespaces: reglas `iptables-legacy` que descartan el tráfico de las redes de Compose | `bash scripts/red-docker-codespace.sh` y repite. Comprobación: `docker exec prod-web1 curl -sI https://deb.debian.org` |
| `Could not find or access '…/app/releases/…'` | Ansible se lanzó fuera de `proyecto/` | `cd proyecto` y repite |
| Tras `scripts/partida.sh`, el terminal dice `getcwd: cannot access parent directories` | El terminal estaba dentro de la carpeta `proyecto/` que se ha sustituido | `cd "$CODESPACE_VSCODE_FOLDER/proyecto"` (la propia salida de `partida.sh` te da la ruta) |
