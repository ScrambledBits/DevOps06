# DevOps06

Ejercicio de clase: infraestructura en AWS con Terraform y configuración con Ansible.

- `terraform/`: VPC con subnets públicas y privadas, 5 frontends detrás de un ALB, un backend privado y MySQL en RDS. Credenciales en Secrets Manager. El código está comentado en español.

```bash
cd terraform
terraform init
terraform apply
```

El estado vive en el bucket S3 `bootcamperu-tf-state`, que debe existir antes del `init`.
