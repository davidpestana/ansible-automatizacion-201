# Nodos de prod con el portal instalado (site.yml) y solo la release 1.0.0:
# se borran las releases de pruebas anteriores para que todas las salidas coincidan.
ansible -i inventories/prod/hosts.yml web -b -m ansible.builtin.file -a "path=/srv/portal state=absent" > /dev/null
ansible-playbook -i inventories/prod/hosts.yml site.yml | sed -n '/PLAY RECAP/,$p'
