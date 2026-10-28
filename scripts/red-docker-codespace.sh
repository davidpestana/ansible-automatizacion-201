#!/usr/bin/env bash
# En algunos Codespaces conviven reglas de iptables-legacy y de nft. Las legacy dejan
# FORWARD en DROP y solo abren docker0, así que los contenedores de una red de Compose
# (interfaces br-*) no se alcanzan entre sí. Este script abre br-* en esas reglas.
# Se puede lanzar varias veces; las reglas se pierden al reiniciar el Codespace.
set -u
if ! command -v iptables-legacy >/dev/null 2>&1; then
  echo "Sin iptables-legacy: no hace falta nada."
  exit 0
fi
if ! sudo iptables-legacy -S FORWARD 2>/dev/null | grep -q -- '-P FORWARD DROP'; then
  echo "FORWARD legacy no descarta tráfico: no hace falta nada."
  exit 0
fi
for sentido in -i -o; do
  if ! sudo iptables-legacy -C FORWARD "$sentido" br-+ -j ACCEPT 2>/dev/null; then
    sudo iptables-legacy -I FORWARD "$sentido" br-+ -j ACCEPT
  fi
done
echo "Redes de Compose abiertas: los contenedores ya se ven entre sí."
