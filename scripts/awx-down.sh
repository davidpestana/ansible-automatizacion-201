#!/usr/bin/env bash
# Borra el clúster de la demo de AWX (los nodos del portal no se tocan).
set -euo pipefail
kind delete cluster --name awx
