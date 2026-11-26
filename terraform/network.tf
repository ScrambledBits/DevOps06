# Un `data` no crea nada: le pregunta a AWS algo que ya existe.
# Aquí pide la lista de zonas de disponibilidad (AZ) activas en us-east-1.
data "aws_availability_zones" "available" {
  # us-east-1e se queda fuera. Es una zona vieja con capacidad limitada y
  # varios tipos de instancia modernos (t3 incluido) no existen en ella.
  exclude_names = ["us-east-1e"]
  state         = "available"
}

# Elige una AZ al azar de esa lista. El resultado se guarda en el estado,
# así que no cambia en cada apply. Solo se vuelve a sortear si cambia la lista de entrada.
resource "random_shuffle" "az" {
  input        = data.aws_availability_zones.available.names
  result_count = 1
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

  # [0] porque random_shuffle devuelve una lista, aunque tenga un solo elemento.
  availability_zone = random_shuffle.az.result[0]

  # Toda instancia lanzada aquí recibe una IP pública automáticamente.
  map_public_ip_on_launch = true

  tags = {
    Name = "Public"
  }
}

# Segunda subnet pública. Existe por una regla del ALB: exige subnets en
# al menos dos AZ distintas, o no se crea.
resource "aws_subnet" "public-2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.4.0/24"

  # Expresión `for`: recorre las AZ disponibles, se queda con las que NO son
  # la de la subnet anterior y toma la primera. Garantiza una AZ diferente.
  availability_zone = [
    for az in data.aws_availability_zones.available.names : az
    if az != aws_subnet.public.availability_zone
  ][0]

  map_public_ip_on_launch = true

  tags = {
    Name = "Public"
  }
}

# Subnet privada: no asigna IPs públicas y su ruta a internet va por el NAT.
# Desde fuera nadie llega directo aquí. Vive en la misma AZ que la pública.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = random_shuffle.az.result[0]

  tags = {
    Name = "Private"
  }
}

# Segunda privada, en otra AZ con el mismo truco del `for`.
# La pide RDS: un DB subnet group necesita subnets en al menos dos AZ.
resource "aws_subnet" "private-2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = [
    for az in data.aws_availability_zones.available.names : az
    if az != aws_subnet.private.availability_zone
  ][0]

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
# Ojo con la factura: un NAT cobra por hora y por GB procesado, aunque esté ocioso.
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
