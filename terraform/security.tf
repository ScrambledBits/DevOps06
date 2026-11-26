# Un security group (SG) es un firewall pegado a la interfaz de red de cada recurso.
# Por defecto bloquea todo lo que entra. Además es stateful: si una conexión
# entró permitida, la respuesta sale sola sin necesitar regla de salida.
#
# Al crear un SG, AWS le pone una regla que permite toda la salida, y el provider
# de Terraform la borra. Por eso existe el SG "all" más abajo: sin él, las
# instancias no podrían iniciar conexiones hacia fuera.
#
# Las reglas van en recursos aparte (aws_vpc_security_group_ingress_rule / egress_rule),
# una por regla. Es la forma recomendada hoy: puedes agregar o quitar una regla
# sin que Terraform reescriba el SG entero.

# SG del frontend: los servidores web públicos.
resource "aws_security_group" "frontend" {
  name        = "frontend"
  description = "Permite el trafico del frontend"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "frontend"
  }
}

# HTTPS (443) desde cualquier IPv4. 0.0.0.0/0 significa "todo internet".
resource "aws_vpc_security_group_ingress_rule" "allow_https_frontend_ipv4" {
  security_group_id = aws_security_group.frontend.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

# HTTP (80) desde cualquier IPv4. Es el puerto por donde también llega el ALB.
resource "aws_vpc_security_group_ingress_rule" "allow_http_frontend_ipv4" {
  security_group_id = aws_security_group.frontend.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# SSH (22) abierto al mundo. Sirve para la clase, pero en un proyecto real
# conviene restringirlo a tu IP (por ejemplo "203.0.113.10/32"): los bots
# escanean el puerto 22 de cualquier IP pública todo el día.
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_frontend_ipv4" {
  security_group_id = aws_security_group.frontend.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

##############################################

# SG del backend: la API que vive en la subnet privada.
resource "aws_security_group" "backend" {
  name        = "backend"
  description = "Permite el trafico del backend"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "backend"
  }
}

# Puerto 5000 (el de la API), pero solo desde dentro de la VPC.
# cidr_ipv4 toma el rango de la propia VPC (10.0.0.0/16), no se escribe a mano.
resource "aws_vpc_security_group_ingress_rule" "allow_http_backend_ipv4" {
  security_group_id = aws_security_group.backend.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 5000
  ip_protocol       = "tcp"
  to_port           = 5000
}

# SSH solo desde la VPC. En la práctica significa: entras al frontend primero
# y de ahí saltas al backend (ver el output backend-login).
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_backend_ipv4" {
  security_group_id = aws_security_group.backend.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}



###########################################

# SG de salida compartido. No permite entrar nada; solo devuelve la salida
# libre que Terraform quitó a los demás. Se adjunta junto al SG propio de cada
# instancia, y AWS suma las reglas de todos los SG que tenga una interfaz.
resource "aws_security_group" "all" {
  name        = "all"
  description = "Permite el trafico de todo"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "all"
  }
}

# "-1" en ip_protocol significa todos los protocolos (TCP, UDP, ICMP...) y todos los
# puertos. Por eso no lleva from_port ni to_port.
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.all.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

###########################################

# SG de la base de datos.
resource "aws_security_group" "db" {
  name        = "db"
  description = "Permite el trafico a la base de datos"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "db"
  }
}

# Aquí la fuente no es un rango de IPs sino otro SG. Se lee así: "deja entrar
# al 3306 a cualquier interfaz que tenga puesto el SG backend".
# Si mañana el backend cambia de IP o se multiplica en diez instancias, la regla sigue valiendo.
# Ni el frontend ni nada de internet llega a MySQL.
resource "aws_vpc_security_group_ingress_rule" "allow_mysql_db_from_backend" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.backend.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}
