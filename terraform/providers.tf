# Bloque de configuración de Terraform en sí, no de la nube. Aquí se declara
# qué plugins (providers) descarga `terraform init` y dónde se guarda el estado.
terraform {
  # Cada provider es un plugin que traduce HCL a llamadas de API.
  # `source` dice de qué registro sale; `version` fija qué versiones se aceptan.
  required_providers {
    # "~> 6.0" acepta cualquier 6.x (6.1, 6.32, etc.) pero nunca 7.0.
    # Las versiones mayores pueden romper recursos, por eso se cierra la puerta ahí.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Los tres siguientes están fijados a una versión exacta. Más predecible,
    # pero hay que subir el número a mano cuando salga una nueva.
    # random: genera valores aleatorios (contraseñas, nombres, AZ) y los recuerda en el estado.
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
    # tls: crea llaves criptográficas sin salir de Terraform (ver ssh.tf).
    tls = {
      source  = "hashicorp/tls"
      version = "4.4.2"
    }
    # local: escribe archivos en tu máquina, como la llave SSH o el inventario de Ansible.
    local = {
      source  = "hashicorp/local"
      version = "2.9.1"
    }
  }

  # El backend decide dónde vive el archivo de estado (.tfstate). Ese archivo es la
  # memoria de Terraform: relaciona cada bloque `resource` con su ID real en AWS.
  # En S3 lo comparte todo el equipo en lugar de quedarse en la computadora de una sola persona.
  backend "s3" {
    bucket = "bootcamperu-tf-state"               # El bucket tiene que existir antes del primer `init`. Se puede crear desde la consola de AWS.
    key    = "estados/terraform-devops06.tfstate" # Ruta del objeto dentro del bucket. Terraform lo crea en el primer `apply` si no existe.
    region = "us-east-1"
    # Cifra el estado en reposo. Hace falta: ahí terminan contraseñas y llaves privadas en texto plano.
    encrypt = true
    # Bloqueo nativo de S3: durante un plan/apply Terraform deja un archivo .tflock junto al estado.
    # Si otra persona lanza un apply a la vez, encuentra el candado y Terraform se detiene con
    # un error en lugar de sobrescribir el estado. Con -lock-timeout=2m esperaría ese tiempo antes de fallar.
    # Antes esto requería una tabla de DynamoDB aparte.
    use_lockfile = true
  }
}


# Configuración del provider de AWS. Todo recurso `aws_*` del proyecto la hereda.
# Las credenciales no van aquí: se leen de ~/.aws o de variables de entorno.
provider "aws" {
  region = "us-east-1"

  # Etiquetas que se pegan solas a cada recurso que acepte tags.
  # Ahorra repetirlas en cada bloque y facilita filtrar costos por equipo.
  default_tags {
    tags = {
      Team  = "DevOps06"
      Owner = "DevOps06"
      # plantimestamp() da la hora en que se calculó el plan y se fija ahí.
      # Con timestamp() el valor sería "desconocido" durante el plan y cada recurso
      # mostraría un cambio de tags en todos los plans, aunque no tocaras nada.
      DateCreated = formatdate("YYYY-MM-DD", plantimestamp())
    }
  }
}
