# Una variable de entrada. Como no tiene `default`, Terraform la pide por teclado
# en cada plan/apply, salvo que llegue por otro lado:
#   terraform apply -var="environment=dev"
#   un archivo terraform.tfvars con: environment = "dev"
#   la variable de entorno TF_VAR_environment=dev
# Sin `type` acepta cualquier valor. Aquí se usa como prefijo del nombre del secreto (secrets.tf).
variable "environment" {
  description = "El ambiente en el que corre la infraestructura"
}
