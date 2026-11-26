# Application Load Balancer (ALB): una sola dirección pública que reparte las
# peticiones HTTP entre los cinco frontends. Si uno se cae, deja de mandarle tráfico.
#
# La cadena completa es:
#   internet -> listener (puerto 80) -> target group -> instancias registradas

# SG propio del ALB. Entra HTTP desde internet y sale todo (hacia las instancias).
resource "aws_security_group" "alb" {
  name        = "alb"
  description = "Trafico HTTP publico hacia el ALB"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# Sin esta salida el ALB no podría abrir conexiones hacia los frontends.
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# El balanceador en sí. internal = false le da un nombre DNS público.
# Exige subnets en al menos dos AZ, y por eso existe public-2 en network.tf.
resource "aws_lb" "frontend" {
  name               = "frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public-2.id]
}

# Target group: el grupo de destinos que recibe el tráfico, en HTTP al puerto 80.
resource "aws_lb_target_group" "frontend" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Cada pocos segundos el ALB hace GET / a cada instancia. Si no responde 200
  # varias veces seguidas, la marca como unhealthy y la saca del reparto.
  # Justo después de crearse aparecen como unhealthy, hasta que cloud-init termina de instalar Caddy.
  health_check {
    path    = "/"
    matcher = "200"
  }
}

# El listener escucha en el puerto 80 del ALB y decide qué hacer con cada petición.
# Aquí no hay reglas: todo se reenvía (forward) al target group.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Fase A: count otra vez, un attachment por cada instancia.
# length() cuenta cuántos frontends hay, así que si cambias count = 5 por 3 en
# compute.tf, esto se ajusta solo. Cada vuelta registra frontend[count.index].
resource "aws_lb_target_group_attachment" "frontend" {
  count            = length(aws_instance.frontend)
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend[count.index].id
  port             = 80
}
