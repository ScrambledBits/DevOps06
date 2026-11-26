# DevOps06

Ejercicio de clase: infraestructura en AWS con Terraform y configuración con Ansible.

- `terraform/`: VPC con subnets públicas y privadas, 5 frontends detrás de un ALB, un backend privado y MySQL en RDS. Credenciales en Secrets Manager. También genera `ansible/inventory.ini`.
- `ansible/`: tres roles. `common` sincroniza la hora con chrony en todos los servidores, `backend` instala una API Flask en el puerto 5000 que consulta MySQL, y `frontend` configura Caddy con una página que muestra qué servidor respondió y reenvía `/api/` al backend.

Todo el código está comentado en español.

## Infraestructura

```bash
cd terraform
terraform init
terraform apply
```

El estado vive en el bucket S3 `bootcamperu-tf-state`, que debe existir antes del `init`.

## Configuración

```bash
cd ansible
ansible-playbook playbook.yaml
```

Requisitos en tu máquina:

- Credenciales de AWS configuradas (las mismas de Terraform): Ansible lee la contraseña de la base desde Secrets Manager.
- La colección `amazon.aws` y `boto3`. Vienen incluidas con el paquete completo `ansible` (por ejemplo, el de Homebrew). Con `ansible-core` solo: `ansible-galaxy collection install amazon.aws` y `boto3` en el mismo Python de Ansible.
- En macOS, antes de correr el playbook: `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` (o agrégalo a `~/.zshrc`). Sin esto, la tarea que lee el secreto falla con `A worker was found in a dead state`: Ansible crea cada worker con `fork()`, boto3 consulta la configuración de proxy del sistema y macOS mata al proceso hijo que usa esas librerías después de un fork. `export no_proxy='*'` también lo evita, pero ignora cualquier proxy que tengas configurado.

Después, abre en el navegador el DNS del ALB: cada recarga puede mostrar otro frontend. `/api/` muestra el backend y el estado de la conexión con MySQL.

Para entrar por SSH al backend, que no tiene IP pública, usa el output `backend-login` de Terraform: salta por el primer frontend.
