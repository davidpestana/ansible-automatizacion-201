# Web de dev y de prod con el portal instalado (web.yml) antes de empezar.
ansible-playbook web.yml | sed -n '/PLAY RECAP/,$p'
ansible-playbook -i inventories/prod/hosts.yml web.yml | sed -n '/PLAY RECAP/,$p'
