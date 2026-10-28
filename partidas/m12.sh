# Nodos de prod con el portal instalado (site.yml) antes de empezar.
ansible-playbook -i inventories/prod/hosts.yml site.yml | sed -n '/PLAY RECAP/,$p'
