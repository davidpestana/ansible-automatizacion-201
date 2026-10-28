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
IMAGEN=tienda-norte/nodo:1

# Una sola ejecución a la vez (postStartCommand y el alumno pueden coincidir)
if [ -z "${NODOS_BLOQUEO:-}" ]; then
  exec 9>"${TMPDIR:-/tmp}/tienda-norte-nodos.lock"
  flock 9
  export NODOS_BLOQUEO=1
fi

clave() {
  # Si Docker arrancó los nodos antes que este script, creó la carpeta del volumen como root
  if [ -d "$CLAVES_DIR" ] && [ ! -w "$CLAVES_DIR" ]; then
    sudo chown -R "$(id -u):$(id -g)" "$HOME/.ssh"
  fi
  if [ ! -f "$CLAVES_DIR/curso_ansible" ]; then
    mkdir -p "$CLAVES_DIR" && chmod 700 "$CLAVES_DIR"
    ssh-keygen -q -t ed25519 -N '' -C curso-ansible -f "$CLAVES_DIR/curso_ansible"
    echo "Clave del curso creada en $CLAVES_DIR/curso_ansible"
    CLAVE_NUEVA=1
  fi
}

imagen() {
  # Cada docker build da un ID nuevo y Compose recrearía los nodos (perdiendo su estado):
  # solo se construye si falta la imagen o ha cambiado infra/nodo/
  local huella
  huella="$(cat "$RAIZ"/infra/nodo/* | sha256sum | cut -c1-16)"
  if [ "$(docker image inspect -f '{{index .Config.Labels "tienda-norte.huella"}}' "$IMAGEN" 2>/dev/null)" != "$huella" ]; then
    docker build -q --label "tienda-norte.huella=$huella" -t "$IMAGEN" "$RAIZ/infra/nodo" >/dev/null
    IMAGEN_NUEVA=1
  fi
}

recrear() {
  # Docker cambia el ID de la imagen en el primer reinicio del Codespace (migra su almacén) y Compose
  # recrearía los nodos: solo se recrean si se reconstruyó la imagen o cambió infra/compose.yaml
  [ -n "${IMAGEN_NUEVA:-}" ] && return 0
  local n
  for n in "${NODOS[@]}"; do
    [ "$(docker inspect -f '{{index .Config.Labels "com.docker.compose.config-hash"}}' "$n" 2>/dev/null)" = \
      "$("${COMPOSE[@]}" config --hash "$n" 2>/dev/null | awk '{print $2}')" ] || return 0
  done
  return 1
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
    imagen
    if recrear; then opciones=(); else opciones=(--no-recreate); fi
    "${COMPOSE[@]}" up -d "${opciones[@]}" 2>&1 | grep -v -e '^ *$' || true
    # Los nodos instalan la clave pública al arrancar: si es nueva, se reinician (conservan su estado)
    if [ -n "${CLAVE_NUEVA:-}" ]; then "${COMPOSE[@]}" restart >/dev/null 2>&1; fi
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
