# dev-web1 con el portal tal como queda tras el lab de group_vars y host_vars (release 1.1.0).
ansible-playbook portal.yml | sed -n '/PLAY RECAP/,$p'
