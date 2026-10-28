# dev-web1 con el portal tal como queda tras el lab de plantillas Jinja2 (portal.conf y estado.json con template).
ansible-playbook portal.yml | sed -n '/PLAY RECAP/,$p'
