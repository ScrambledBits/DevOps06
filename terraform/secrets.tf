# Flujo de este archivo: se generan usuario y contraseña al azar, se guardan
# en AWS Secrets Manager y la base de datos los vuelve a leer de ahí.
# Así las credenciales nunca se escriben a mano en el código.

# El contenedor del secreto, todavía sin contenido. El nombre queda, por ejemplo, "dev/dbcreds".
resource "aws_secretsmanager_secret" "dbcreds" {
  name = "${var.environment}/dbcreds"
  # Borra el secreto en el acto al hacer destroy. Sin esto AWS lo retiene 30 días
  # por si necesitas recuperarlo, y en ese tiempo el nombre queda ocupado: el siguiente apply falla.
  recovery_window_in_days = 0
}

# El contenido real del secreto. Un secreto puede tener muchas versiones; esta es la actual.
# jsonencode convierte el mapa de abajo en texto: {"password":"<contraseña>","user":"<usuario>"}
resource "aws_secretsmanager_secret_version" "creds" {
  secret_id     = aws_secretsmanager_secret.dbcreds.id
  secret_string = jsonencode(local.dbcreds)
}

# Lee el secreto de vuelta desde AWS. La DB toma sus credenciales de esta lectura
# y no directo de local.dbcreds, para que el ejemplo muestre cómo se consume un
# secreto que ya existe.
data "aws_secretsmanager_secret_version" "db-credentials" {
  secret_id = aws_secretsmanager_secret.dbcreds.id
  # depends_on fuerza el orden cuando no hay una referencia directa que lo marque.
  # Sin él, Terraform podría leer el secreto antes de que tenga versión y la lectura falla.
  depends_on = [aws_secretsmanager_secret_version.creds]
}

# Un `locals` es un valor con nombre para no repetir expresiones.
# Junta usuario y contraseña en un mapa que se usa arriba y en outputs.tf.
locals {
  dbcreds = {
    user     = random_pet.dbuser.id
    password = random_password.db-password.result
  }
}

# Contraseña de 32 caracteres. `result` se marca como sensible y no aparece en el plan.
resource "random_password" "db-password" {
  length  = 32
  special = true
  # Lista cerrada de símbolos permitidos. RDS rechaza "/", "@", comillas dobles
  # y espacios en la contraseña maestra; aquí simplemente no están.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Nombre de usuario aleatorio y legible, como "walrus" o "falcon".
resource "random_pet" "dbuser" {
  # Sin keepers ligados a la DB: rompe el ciclo DB -> secreto -> random_pet -> DB.
  # Una sola palabra porque RDS no acepta guiones en el usuario maestro de MySQL,
  # y con length = 2 saldría algo como "happy-walrus".
  length = 1
}
