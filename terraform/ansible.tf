# Aquí Terraform le entrega el trabajo a Ansible. Rellena la plantilla del
# inventario con lo que acaba de crear (IPs, endpoint de la base, nombre del
# secreto) y la escribe en ../ansible/inventory.ini. Después de cada apply,
# Ansible ya sabe a qué máquinas conectarse sin copiar IPs a mano.

# La región que usa el provider de AWS. Ansible la necesita para leer el
# secreto de la base de datos desde Secrets Manager.
data "aws_region" "current" {}

# templatefile() recibe la ruta de la plantilla y un mapa de variables. Cada
# clave del mapa se usa dentro de la plantilla como ${clave}.
resource "local_file" "ansible-inventory" {
  content = templatefile("${path.module}/templates/inventory.ini.tpl", {
    frontend_ips = local.frontend-ips
    # El primer frontend hace de bastión: es el salto para llegar al backend.
    bastion_ip = local.frontend-ips[0]
    # Los backends solo tienen IP privada; Ansible llega a ellas a través del bastión.
    # El splat [*] arma la lista con la IP privada de cada backend.
    backend_ips = aws_instance.backend[*].private_ip
    # abspath() vuelve absoluta la ruta de la llave, así el inventario funciona
    # sin importar desde qué carpeta ejecutes Ansible.
    ssh_key = abspath(local.ssh-key)
    # address es solo el nombre DNS de RDS; endpoint (usado en outputs.tf) trae además ":3306".
    db_host = aws_db_instance.db-1.address
    db_name = aws_db_instance.db-1.db_name
    # Solo el nombre del secreto, nunca la contraseña: Ansible la lee en el momento del despliegue.
    db_secret_name = aws_secretsmanager_secret.dbcreds.name
    aws_region     = data.aws_region.current.region
  })
  filename = "${path.module}/../ansible/inventory.ini"
}
