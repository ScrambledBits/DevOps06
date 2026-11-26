# Un `data` no crea nada: le pregunta a AWS algo que ya existe.
# Aquí pide la lista de zonas de disponibilidad (AZ) activas en la región.
data "aws_availability_zones" "available" {
  state = "available"
}

# Una zona puede estar activa y aun así no ofrecer el tipo de instancia que
# usamos. En us-east-1, por ejemplo, us-east-1e no tiene t3.micro. Este data
# source pregunta en qué zonas sí se ofrece local.instance_type (compute.tf).
data "aws_ec2_instance_type_offerings" "instance_type" {
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [local.instance_type]
  }
}

locals {
  # Zonas que cumplen las dos condiciones: activas y con el tipo de instancia.
  # setintersection devuelve un conjunto sin orden; sort lo vuelve una lista
  # ordenada, así la entrada del sorteo es estable entre un plan y otro.
  azs = sort(setintersection(
    data.aws_availability_zones.available.names,
    data.aws_ec2_instance_type_offerings.instance_type.locations,
  ))
}

# Sortea dos AZ distintas de esa lista: result[0] es la zona A y result[1] la B.
# El resultado se guarda en el estado, así que no cambia en cada apply. Solo se
# vuelve a sortear si cambia la lista de entrada o result_count.
resource "random_shuffle" "az" {
  input        = local.azs
  result_count = 2

  lifecycle {
    # Si la región tuviera menos de dos zonas válidas, result[1] no existiría y
    # el error sería confuso. La precondición falla antes con un mensaje claro.
    precondition {
      condition     = length(local.azs) >= 2
      error_message = "Se necesitan al menos 2 AZ que ofrezcan ${local.instance_type}."
    }
  }
}

# La VPC es tu red privada dentro de AWS. 10.0.0.0/16 te da 65,536 direcciones
# para repartir entre subnets. Nada entra ni sale de ella hasta que lo permitas.
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Role = "Primary"
    Name = "DevOps06-VPC"
  }
}

# Primera subnet pública: 10.0.1.0/24, 256 direcciones (AWS se reserva 5).
# Lo que la hace "pública" es su route table, que apunta al internet gateway (más abajo).
resource "aws_subnet" "public" {
  # Referencia explícita: al leer aws_vpc.main.id, Terraform sabe que debe crear
  # la VPC primero. Así arma el orden de creación sin que se lo digas.
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  # Zona A del sorteo.
  availability_zone = random_shuffle.az.result[0]

  # Toda instancia lanzada aquí recibe una IP pública automáticamente.
  map_public_ip_on_launch = true

  tags = {
    Name = "Public"
  }
}

# Segunda subnet pública, en la zona B. El ALB exige subnets en al menos dos AZ
# distintas, y aquí también viven la mitad de los frontends.
resource "aws_subnet" "public-2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.4.0/24"

  # Zona B del sorteo. random_shuffle nunca repite un elemento, así que es
  # distinta de la zona A.
  availability_zone = random_shuffle.az.result[1]

  map_public_ip_on_launch = true

  tags = {
    Name = "Public"
  }
}

# Subnet privada: no asigna IPs públicas y su ruta a internet va por el NAT.
# Desde fuera nadie llega directo aquí. Vive en la zona A, como public.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = random_shuffle.az.result[0]

  tags = {
    Name = "Private"
  }
}

# Segunda privada, en la zona B como public-2. La pide RDS (un DB subnet group
# necesita subnets en al menos dos AZ) y aquí vive el segundo backend.
resource "aws_subnet" "private-2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = random_shuffle.az.result[1]

  tags = {
    Name = "Private"
  }
}

# El internet gateway es la puerta de la VPC hacia internet, en ambos sentidos.
# Crearlo no basta: una route table tiene que mandar tráfico hacia él.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

# NAT gateway: deja que las máquinas privadas salgan a internet (apt update, descargas)
# sin que nadie de fuera pueda iniciar una conexión hacia ellas.
# Modo "regional" (disponible desde noviembre de 2025): se pide sobre la VPC, sin subnet_id,
# y AWS lo extiende solo a las AZ donde tengas recursos. El modo zonal clásico obligaba
# a crear uno por AZ dentro de una subnet pública.
# Cuidado con el costo: un NAT cobra por hora y por GB procesado, aunque no tenga tráfico.
resource "aws_nat_gateway" "nat-gw" {
  vpc_id            = aws_vpc.main.id
  availability_mode = "regional"
}


# Lista de subnets donde RDS puede colocar la base de datos.
# Solo privadas: la DB nunca debería tener cara hacia internet.
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.private-2.id, aws_subnet.private.id]

  tags = {
    Name = "Devops06 Subnet Group"
  }
}

# Christopher tenía razón, hace falta crear las route tables.
# Sin ellas las subnets usan la route table principal de la VPC, que solo conoce
# la ruta local (10.0.0.0/16). Nada sale a internet.

# Route table pública: todo lo que no sea tráfico interno va al internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # `route` es un bloque anidado: se escribe sin "=".
  # 0.0.0.0/0 es la ruta por defecto, "cualquier destino que no conozca".
  # La ruta local de la VPC la agrega AWS solo y no hace falta declararla.
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public"
  }
}

# Una route table no sirve de nada hasta que la asocias a una subnet.
# Cada asociación es un recurso aparte: una por subnet.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.public.id
}

# Route table privada. Misma ruta por defecto, pero el siguiente salto es el NAT.
# Las subnets privadas salen a internet sin recibir tráfico entrante.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }

  tags = {
    Name = "Private"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private-2" {
  subnet_id      = aws_subnet.private-2.id
  route_table_id = aws_route_table.private.id
}
