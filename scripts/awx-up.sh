#!/usr/bin/env bash
# Levanta AWX para la demo del M11: clúster kind «awx», AWX Operator y la instancia.
# Pide un Codespace de 4 núcleos y 16 GB. Tarda varios minutos (descarga de imágenes).
# Al terminar: http://localhost:8043 con el usuario admin y la contraseña que imprime.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER=awx
NODOS_RED=tienda-norte_portal

for herramienta in kind kubectl; do
  if ! command -v "$herramienta" >/dev/null 2>&1; then
    echo "Falta $herramienta: crea el Codespace con la configuración «Ansible — Tienda Norte + AWX (demo M11)» (.devcontainer/awx/)." >&2
    exit 1
  fi
done
COREFILE="$(mktemp)"
trap 'rm -f "$COREFILE" "$COREFILE.nuevo"' EXIT

# Si los nodos ya corren no se tocan: recrearlos borraría lo que dejó scripts/partida.sh.
if [ "$(docker ps -q --filter name=^prod- | wc -l)" -lt 4 ]; then
  bash "$RAIZ/scripts/nodos.sh" up >/dev/null
fi
bash "$RAIZ/scripts/kind-net-fix.sh" || true
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
    kind create cluster --name "$CLUSTER" --config "$RAIZ/infra/awx/kind.yaml"
fi
bash "$RAIZ/scripts/kind-net-fix.sh" || true
kubectl config use-context "kind-$CLUSTER" >/dev/null

# El nodo de kind entra en la red de los nodos del portal y CoreDNS resuelve sus nombres:
# así AWX llega a prod-web1, prod-lb1… igual que el Codespace.
docker network connect "$NODOS_RED" "$CLUSTER-control-plane" 2>/dev/null || true
HOSTS=$(awk '/^Host [a-z]/{h=$2} /HostName/{print "           " $2 " " h}' "$RAIZ/infra/ssh_config")
kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' > $COREFILE
if ! grep -q 'hosts {' $COREFILE; then
  awk -v hosts="$HOSTS" '{print} /^\.:53 \{/{print "        hosts {"; print hosts; print "           fallthrough"; print "        }"}' $COREFILE > $COREFILE.nuevo
  kubectl -n kube-system create configmap coredns --from-file=Corefile=$COREFILE.nuevo --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n kube-system rollout restart deploy/coredns
fi

kubectl create namespace awx --dry-run=client -o yaml | kubectl apply -f -
# La primera vez el recurso AWX llega antes de que exista su CRD: se aplica otra vez cuando ya está.
kubectl apply -k "$RAIZ/infra/awx" 2>/dev/null || true
kubectl wait --for=condition=Established crd/awxs.awx.ansible.com --timeout=120s
kubectl apply -k "$RAIZ/infra/awx"
echo "Esperando a AWX (varios minutos la primera vez)…"
for _ in $(seq 1 120); do
  if kubectl -n awx get deploy awx-web >/dev/null 2>&1; then break; fi
  sleep 10
done
kubectl -n awx rollout status deploy/awx-web --timeout=1200s
kubectl -n awx rollout status deploy/awx-task --timeout=600s
until curl -fs http://localhost:8043/api/v2/ping/ >/dev/null; do sleep 5; done
echo
echo "AWX listo: http://localhost:8043"
echo "Usuario: admin"
echo "Contraseña: $(kubectl -n awx get secret awx-admin-password -o jsonpath='{.data.password}' | base64 -d)"
