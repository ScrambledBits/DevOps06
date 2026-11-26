# Inventario generado por Terraform (terraform/ansible.tf). No lo edites a
# mano: el próximo terraform apply lo sobrescribe.

# Los servidores web. El nombre de la izquierda es el inventory_hostname que
# ve Ansible; ansible_host es la IP real a la que se conecta por SSH.
[frontend]
%{ for i, ip in frontend_ips ~}
frontend-${i} ansible_host=${ip}
%{ endfor }
# El backend solo tiene IP privada: desde tu máquina no se llega directo.
# El host se llama backend-0 y no "backend" porque un host y un grupo con el
# mismo nombre confunden a Ansible (y lo advierte con un warning).
[backend]
backend-0 ansible_host=${backend_ip}

# Variables para todos los hosts.
[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=${ssh_key}
# accept-new guarda sin preguntar la huella SSH de un servidor nuevo, pero
# rechaza la conexión si la huella de uno ya conocido cambia.
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'

# Variables solo para el grupo backend. backend es un grupo hijo de all, así
# que sus valores ganan: este ansible_ssh_common_args reemplaza al de arriba.
[backend:vars]
# ProxyCommand abre primero un SSH al bastión (frontend-0) y, con -W, reenvía
# desde ahí la conexión a la IP privada del backend (%h host, %p puerto).
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new -o ProxyCommand="ssh -i ${ssh_key} -o StrictHostKeyChecking=accept-new -W %h:%p ubuntu@${bastion_ip}"'
# Datos de la base que usa el rol backend. La contraseña no está aquí: Ansible
# la lee de Secrets Manager en el momento del despliegue.
db_host=${db_host}
db_name=${db_name}
db_secret_name=${db_secret_name}
aws_region=${aws_region}
