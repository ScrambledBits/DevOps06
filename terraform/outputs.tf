# Valores calculados una vez y reutilizados abajo y en ansible.tf.
locals {
  # El splat [*] saca un atributo de cada elemento de una lista.
  # Equivale a [for i in aws_instance.frontend : i.public_ip]: una lista de 5 IPs.
  frontend-ips = aws_instance.frontend[*].public_ip
  # El endpoint de RDS ya trae el puerto: "algo.rds.amazonaws.com:3306".
  db-endpoint = aws_db_instance.db-1.endpoint
  ssh-key     = local_sensitive_file.ssh-key.filename
}

# Los outputs se imprimen al final de cada apply. Para verlos otra vez
# sin aplicar nada: `terraform output` o `terraform output frontend-login`.

output "frontend-ip" {
  description = "Las IPs de la instancias frontend"
  value       = local.frontend-ips
}

# Arma el comando ssh listo para copiar y pegar, contra el primer frontend ([0]).
# ubuntu es el usuario por defecto en las AMI de Canonical.
output "frontend-login" {
  description = "El string para hacer login a la instancia del frontend"
  value       = "ssh -i ${local.ssh-key} ubuntu@${local.frontend-ips[0]}"
}

output "db-endpoint" {
  value = "El endpoint de la DB es ${local.db-endpoint}"
}

# Solo el usuario. La contraseña se consulta en Secrets Manager, no se imprime en pantalla.
output "db-user" {
  description = "El nombre de usuario para la base de datos"
  value       = local.dbcreds["user"]
}

# El backend no tiene IP pública: se entra saltando por el frontend, que hace de bastión.
# ProxyCommand abre primero un ssh al frontend y con -W %h:%p reenvía la conexión
# a la IP privada del backend (%h host, %p puerto). Las dos conexiones usan la misma llave.
# `ssh -J ubuntu@<frontend>` hace lo mismo con menos texto, pero tiene un detalle:
# no pasa el -i al salto y depende de que la llave esté en tu agente SSH.
output "backend-login" {
  description = "El string para hacer login a la instancia del backend a traves del frontend"
  value       = "ssh -i ${local.ssh-key} -o ProxyCommand=\"ssh -i ${local.ssh-key} -W %h:%p ubuntu@${local.frontend-ips[0]}\" ubuntu@${aws_instance.backend.private_ip}"
}
