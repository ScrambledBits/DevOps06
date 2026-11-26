# Busca el ID de la imagen (AMI) de Ubuntu más reciente. Los IDs cambian con cada
# publicación y son distintos en cada región, así que escribirlos a mano envejece mal.
data "aws_ami" "operating-system" {
  # Si varias imágenes coinciden con los filtros, toma la más nueva.
  most_recent = true

  filter {
    name = "name"
    # Ubuntu 24.04 LTS (noble). Sus imágenes usan "hvm-ssd-gp3" en vez de "hvm-ssd".
    # El "*" final cubre la fecha de publicación que lleva cada imagen.
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Cuenta de AWS de Canonical. Sin este filtro cualquiera podría publicar una
  # AMI con el mismo nombre y colártela.
  owners = ["099720109477"]
}

# Cinco servidores web idénticos en la subnet pública.
resource "aws_instance" "frontend" {
  ami           = data.aws_ami.operating-system.id
  instance_type = "t3.micro"

  # count convierte este bloque en una lista de 5 instancias:
  # aws_instance.frontend[0] hasta aws_instance.frontend[4].
  count = 5

  associate_public_ip_address = true

  subnet_id = aws_subnet.public.id

  # Dos SG a la vez: "all" para poder salir a internet y "frontend" para recibir 22/80/443.
  vpc_security_group_ids = [aws_security_group.all.id, aws_security_group.frontend.id]

  key_name = aws_key_pair.bootcamperu-deployer.key_name

  # Script que cloud-init ejecuta en el primer arranque. Este actualiza paquetes
  # e instala Caddy como servidor web. El {} es el mapa de variables de la plantilla,
  # vacío porque no usa ninguna.
  user_data = templatefile("${path.module}/templates/frontend-cloud-init.yml", {})

  # Exige IMDSv2: para leer los metadatos de la instancia (credenciales de IAM incluidas)
  # primero hay que pedir un token. Corta los ataques SSRF que robaban credenciales con
  # un simple GET a 169.254.169.254.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    # count.index es el número de cada copia: "Frontend 0", "Frontend 1"...
    Name = "Frontend ${count.index}"
  }
}

# Un único backend en la subnet privada. Sin IP pública: solo se llega desde la VPC.
resource "aws_instance" "backend" {
  ami           = data.aws_ami.operating-system.id
  instance_type = "t3.micro"

  subnet_id = aws_subnet.private.id

  vpc_security_group_ids = [aws_security_group.all.id, aws_security_group.backend.id]

  key_name = aws_key_pair.bootcamperu-deployer.key_name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "Backend"
  }
}

# Base de datos MySQL administrada por AWS (RDS). AWS se encarga del sistema
# operativo, los parches y los backups. Tú solo ves el endpoint.
# Tarda unos 5 a 10 minutos en crearse; es lo más lento de todo el apply.
resource "aws_db_instance" "db-1" {
  # RDS MySQL exige mínimo 20 GiB de almacenamiento.
  allocated_storage = 20
  # Base de datos que se crea vacía al arrancar.
  db_name = "mydb"
  engine  = "mysql"
  # Solo la versión mayor: AWS elige la menor más reciente de la 8.0.
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  # Coloca la DB en las subnets privadas definidas en network.tf.
  db_subnet_group_name = aws_db_subnet_group.default.id
  # secret_string es texto JSON. jsondecode lo vuelve mapa y ["user"] saca un campo.
  username = jsondecode(data.aws_secretsmanager_secret_version.db-credentials.secret_string)["user"]
  password = jsondecode(data.aws_secretsmanager_secret_version.db-credentials.secret_string)["password"]
  # Parámetros de MySQL que trae AWS por defecto.
  parameter_group_name = "default.mysql8.0"
  # En destroy no guarda un snapshot final. Cómodo en clase; en producción
  # perderías los datos de un plumazo.
  skip_final_snapshot = true
  # Sin esto RDS usa el SG por defecto de la VPC y el backend no llega al puerto 3306.
  vpc_security_group_ids = [aws_security_group.db.id]
}
