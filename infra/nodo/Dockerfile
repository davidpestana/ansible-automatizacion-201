# Nodo gestionado del portal de Tienda Norte: Debian con SSH y Python, sin agente de Ansible.
FROM debian:13-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server python3 python3-apt sudo ca-certificates curl procps \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin \
 # Caché de apt «caducada»: el primer apt con cache_valid_time actualiza la lista de paquetes
 && touch -d 2000-01-01 /var/lib/apt/lists \
 && useradd -m -s /bin/bash ansible \
 && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
 && mkdir -p /run/sshd /home/ansible/.ssh \
 && chown ansible:ansible /home/ansible/.ssh && chmod 700 /home/ansible/.ssh
COPY arranque.sh /usr/local/bin/arranque.sh
EXPOSE 22 80
CMD ["/usr/local/bin/arranque.sh"]
