#!/bin/sh
# Instala la clave pública del curso y deja sshd en primer plano.
set -e
if [ -f /run/claves/curso_ansible.pub ]; then
  install -o ansible -g ansible -m 600 /run/claves/curso_ansible.pub /home/ansible/.ssh/authorized_keys
fi
[ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -A
exec /usr/sbin/sshd -D -e
