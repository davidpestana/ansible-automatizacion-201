#!/usr/bin/env bash
# Codespaces (Docker 29): la red Docker "kind" no tiene NAT a Internet
# y, con br_netfilter, los nodos ni siquiera se hablan entre sí.
# Este script:
# 1) Crea esa red solo IPv4 (evita ip6tables).
# 2) Apaga bridge-nf-call-iptables para que kubeadm join llegue a :6443.
# 3) Levanta un proxy CONNECT en la gateway de kind (el host SÍ tiene red).
# 4) Configura containerd de cada nodo con HTTPS_PROXY → kubelet puede hacer pull.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROXY_PORT="${KIND_EGRESS_PORT:-3128}"

log() { echo "[kind-net-fix] $*"; }

if ! command -v docker >/dev/null 2>&1; then
  exit 0
fi
if ! docker info >/dev/null 2>&1; then
  exit 0
fi

write_sysctl() {
  local path="$1" val="$2"
  if [ ! -e "$path" ]; then
    return 0
  fi
  if [ -w "$path" ]; then
    echo "$val" >"$path" 2>/dev/null || true
  elif command -v sudo >/dev/null 2>&1; then
    echo "$val" | sudo -n tee "$path" >/dev/null 2>&1 || true
  fi
}

iptables_try() {
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo iptables "$@"
  else
    iptables "$@"
  fi
}

# Sin esto, Docker 29 mete el puente kind en iptables FORWARD y
# "Joining worker nodes" se queda colgado (worker ↛ API :6443).
relax_kind_bridge() {
  write_sysctl /proc/sys/net/bridge/bridge-nf-call-iptables 0
  write_sysctl /proc/sys/net/bridge/bridge-nf-call-ip6tables 0
  write_sysctl /proc/sys/net/ipv4/ip_forward 1
  iptables_try -C FORWARD -m physdev --physdev-is-bridged -j ACCEPT 2>/dev/null \
    || iptables_try -I FORWARD 1 -m physdev --physdev-is-bridged -j ACCEPT 2>/dev/null \
    || true
}

if [ -w /proc/sys/net/ipv4/ip_forward ]; then
  echo 1 >/proc/sys/net/ipv4/ip_forward 2>/dev/null || true
fi
modprobe ip6_tables 2>/dev/null || true
modprobe br_netfilter 2>/dev/null || true
relax_kind_bridge

ensure_kind_network() {
  if docker network inspect kind >/dev/null 2>&1; then
    local n
    n="$(docker network inspect kind -f '{{len .Containers}}' 2>/dev/null || echo 1)"
    if [ "${n}" = "0" ]; then
      log "recreando red kind vacía (IPv4)"
      docker network rm kind >/dev/null 2>&1 || return 0
    else
      return 0
    fi
  fi
  log "creando red docker kind solo IPv4"
  docker network create \
    --driver bridge \
    -o com.docker.network.bridge.enable_ip_masquerade=true \
    kind >/dev/null
}

kind_gateway() {
  docker network inspect kind -f '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || echo "172.18.0.1"
}

ensure_egress_proxy() {
  local gw="$1"
  if ss -ltn 2>/dev/null | grep -q "${gw}:${PROXY_PORT}"; then
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    log "python3 no está; el proxy de salida no arranca"
    return 1
  fi
  log "proxy CONNECT en ${gw}:${PROXY_PORT} (imagenes kind → Internet del Codespace)"
  nohup python3 "$ROOT/scripts/kind-egress-proxy.py" "$gw" "$PROXY_PORT" \
    >/tmp/kind-egress-proxy.log 2>&1 &
  sleep 0.5
}

configure_node_containerd_proxy() {
  local node="$1" gw="$2"
  local proxy="http://${gw}:${PROXY_PORT}"
  local nop="localhost,127.0.0.1,10.96.0.0/16,10.244.0.0/16,172.16.0.0/12,.svc,.cluster.local"
  docker exec "$node" bash -c "
set -e
dropin=/etc/systemd/system/containerd.service.d/http-proxy.conf
mkdir -p /etc/systemd/system/containerd.service.d
need_restart=0
if [ ! -f \"\$dropin\" ] || ! grep -q \"HTTPS_PROXY=${proxy}\" \"\$dropin\"; then
  cat > \"\$dropin\" <<EOF
[Service]
Environment=HTTP_PROXY=${proxy}
Environment=HTTPS_PROXY=${proxy}
Environment=NO_PROXY=${nop}
EOF
  need_restart=1
fi
cid=\$(pgrep -x containerd | head -1 || true)
if [ -z \"\$cid\" ] || ! tr '\\0' '\\n' < /proc/\$cid/environ 2>/dev/null | grep -qx \"HTTPS_PROXY=${proxy}\"; then
  need_restart=1
fi
if [ \"\$need_restart\" != 1 ]; then
  exit 0
fi
systemctl daemon-reload
systemctl restart containerd
sleep 1
systemctl restart kubelet || true
" 2>/dev/null && log "containerd usa proxy en ${node}" || log "AVISO: no pude poner proxy en ${node}"
}

ensure_kind_network || true
GW="$(kind_gateway)"
ensure_egress_proxy "$GW" || true

export KIND_HTTP_PROXY="http://${GW}:${PROXY_PORT}"
export KIND_HTTPS_PROXY="http://${GW}:${PROXY_PORT}"
export KIND_NO_PROXY="localhost,127.0.0.1,10.96.0.0/16,10.244.0.0/16,172.16.0.0/12,.svc,.cluster.local"

for node in $(docker ps --filter "label=io.x-k8s.kind.cluster" --format '{{.Names}}' 2>/dev/null); do
  configure_node_containerd_proxy "$node" "$GW"
done

# Docker puede reactivar br_netfilter al crear la red o arrancar nodos.
relax_kind_bridge

exit 0
