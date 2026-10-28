# Punto de entrada del proyecto: todas las ejecuciones pasan por aquí.
#   make check ENTORNO=pre            simula el site.yml sin cambiar nada (nodos ya instalados)
#   make deploy ENTORNO=prod VERSION=1.1.0 CONFIRMAR=si
ENTORNO ?= dev
VERSION ?=
INVENTARIO := inventories/$(ENTORNO)/hosts.yml
PLAYBOOKS := site.yml deploy.yml

.PHONY: ayuda lint syntax check validar site deploy ping confirmar

ayuda:
	@echo "Objetivos: lint syntax check validar site deploy ping  (ENTORNO=dev|pre|prod, VERSION=x.y.z)"

ping:
	ansible all -i $(INVENTARIO) -m ansible.builtin.ping

lint:
	ansible-lint $(PLAYBOOKS)

syntax:
	@for p in $(PLAYBOOKS); do ansible-playbook -i $(INVENTARIO) $$p --syntax-check || exit 1; done

check:
	ansible-playbook -i $(INVENTARIO) site.yml --check --diff

validar: lint syntax

site: validar confirmar
	ansible-playbook -i $(INVENTARIO) site.yml

deploy: validar check confirmar
	@test -n "$(VERSION)" || { echo "Falta VERSION=x.y.z"; exit 2; }
	ansible-playbook -i $(INVENTARIO) deploy.yml -e portal_version=$(VERSION)

confirmar:
	@if [ "$(ENTORNO)" = "prod" ] && [ "$(CONFIRMAR)" != "si" ]; then \
	  echo "prod pide CONFIRMAR=si"; exit 2; fi
