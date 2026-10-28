#!/usr/bin/env bash
# Deja proyecto/ en el punto de partida de una página y prepara los nodos.
#   scripts/partida.sh <estado> [--limpio]
#     <estado>   carpeta de partidas/ (p. ej. m04, m07-02)
#     --limpio   recrea los nodos desde cero (sin nginx ni portal) antes de preparar
# Lo que hubiera en proyecto/ se guarda en proyecto.anterior/.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
ESTADO="${1:-}"
if [ -z "$ESTADO" ] || [ ! -d "$RAIZ/partidas/$ESTADO" ]; then
  echo "Uso: $0 <estado> [--limpio]   estados: $(ls "$RAIZ/partidas" | grep -v '\.sh$' | tr '\n' ' ')" >&2
  exit 2
fi
if [ "${2:-}" = "--limpio" ]; then
  bash "$RAIZ/scripts/nodos.sh" reset
else
  bash "$RAIZ/scripts/nodos.sh" up >/dev/null
fi
if [ -d "$RAIZ/proyecto" ]; then
  rm -rf "$RAIZ/proyecto.anterior"
  mv "$RAIZ/proyecto" "$RAIZ/proyecto.anterior"
fi
cp -r "$RAIZ/partidas/$ESTADO" "$RAIZ/proyecto"
if [ -f "$RAIZ/partidas/$ESTADO.sh" ]; then
  echo "Preparando los nodos para $ESTADO…"
  (cd "$RAIZ/proyecto" && bash "$RAIZ/partidas/$ESTADO.sh")
fi
echo "Listo: proyecto/ en el punto de partida «$ESTADO» (lo anterior está en proyecto.anterior/)."
echo "Entra en él con: cd $RAIZ/proyecto"
