#!/usr/bin/env bash
# Nodos del portal de Tienda Norte (contenedores con SSH).
#   scripts/nodos.sh up      crea la clave del curso si falta y levanta los 6 nodos
#   scripts/nodos.sh reset   borra los nodos y los crea limpios (sin nginx ni portal)
#   scripts/nodos.sh down    los para y los borra
#   scripts/nodos.sh estado  lista los nodos y comprueba el SSH de cada uno
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
export CLAVES_DIR="${CLAVES_DIR:-$HOME/.ssh/curso-ansible}"
COMPOSE=(docker compose -f "$RAIZ/infra/compose.yaml")
NODOS=(dev-web1 pre-web1 prod-lb1 prod-web1 prod-web2 prod-db1)

clave() {
  if [ ! -f "$CLAVES_DIR/curso_ansible" ]; then
    mkdir -p "$CLAVES_DIR" && chmod 700 "$CLAVES_DIR"
    ssh-keygen -q -t ed25519 -N '' -C curso-ansible -f "$CLAVES_DIR/curso_ansible"
    echo "Clave del curso creada en $CLAVES_DIR/curso_ansible"
  fi
}

esperar_ssh() {
  for n in "${NODOS[@]}"; do
    for _ in $(seq 1 30); do
      if ssh -F "$RAIZ/infra/ssh_config" -i "$CLAVES_DIR/curso_ansible" -o BatchMode=yes -o ConnectTimeout=2 "$n" true 2>/dev/null; then
        break
      fi
      sleep 1
    done
  done
}

estado() {
  for n in "${NODOS[@]}"; do
    if ssh -F "$RAIZ/infra/ssh_config" -i "$CLAVES_DIR/curso_ansible" -o BatchMode=yes -o ConnectTimeout=3 "$n" true 2>/dev/null; then
      printf '%-10s SSH ok\n' "$n"
    else
      printf '%-10s SIN SSH\n' "$n"
    fi
  done
}

case "${1:-up}" in
  up)
    clave
    bash "$RAIZ/scripts/red-docker-codespace.sh" >/dev/null 2>&1 || true
    docker build -q -t tienda-norte/nodo:1 "$RAIZ/infra/nodo" >/dev/null
    "${COMPOSE[@]}" up -d 2>&1 | grep -v -e '^ *$' || true
    esperar_ssh; estado ;;
  reset)
    "${COMPOSE[@]}" down -v --remove-orphans
    "$0" up ;;
  down)
    "${COMPOSE[@]}" down -v --remove-orphans ;;
  estado)
    estado ;;
  *)
    echo "Uso: $0 up|reset|down|estado" >&2; exit 2 ;;
esac
