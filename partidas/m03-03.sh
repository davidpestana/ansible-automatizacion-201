# Nodo de dev con el portal aplicado (portal.yml) antes de empezar.
ansible-playbook portal.yml | sed -n '/PLAY RECAP/,$p'
