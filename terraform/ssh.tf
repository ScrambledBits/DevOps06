# Genera un par de llaves (privada + pública) dentro de Terraform.
# ED25519 es el algoritmo moderno: llaves cortas, rápidas y seguras.
# La llave privada queda guardada en el estado sin cifrar. Por eso el backend
# tiene encrypt = true y por eso nadie debería subir un .tfstate a git.
resource "tls_private_key" "bootcamperu-key" {
  algorithm = "ED25519"
}

# Escribe la llave privada en un archivo local para poder usarla con `ssh -i`.
# "sensitive" hace que Terraform no muestre su contenido en el plan.
resource "local_sensitive_file" "ssh-key" {
  # Formato OpenSSH: ssh no sabe leer llaves ED25519 en formato PEM (PKCS#8).
  content = tls_private_key.bootcamperu-key.private_key_openssh
  # path.module es la carpeta de este código, así que el archivo queda en terraform/ssh-key.key.
  filename = "${path.module}/ssh-key.key"
  # 0600 = solo tu usuario puede leer y escribir. Con permisos más abiertos,
  # ssh se niega a usar la llave ("UNPROTECTED PRIVATE KEY FILE").
  file_permission = "0600"
}

# Sube la mitad pública a AWS con el nombre "deployer-key".
# Las instancias que la referencian (key_name en compute.tf) la copian a
# ~/.ssh/authorized_keys del usuario ubuntu al arrancar.
resource "aws_key_pair" "bootcamperu-deployer" {
  key_name   = "deployer-key"
  public_key = tls_private_key.bootcamperu-key.public_key_openssh
}
