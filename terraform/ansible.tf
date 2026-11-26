# Aquí Terraform le entrega el trabajo a Ansible. Toma las IPs públicas de los frontends,
# rellena la plantilla del inventario y la escribe en ../ansible/inventory.ini.
# Después de cada apply, Ansible ya sabe a qué máquinas conectarse sin copiar IPs a mano.
#
# templatefile() recibe la ruta de la plantilla y un mapa de variables. Dentro de la
# plantilla, `ips` es la lista que se recorre con %{ for ip_address in ips }.
# El archivo de plantilla se llama "inventoy.ini.tpl" (sin la r), y la ruta tiene que coincidir así.
resource "local_file" "ansible-inventory" {
  content  = templatefile("${path.module}/templates/inventoy.ini.tpl", { ips = local.frontend-ips })
  filename = "${path.module}/../ansible/inventory.ini"
}
