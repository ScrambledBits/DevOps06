# Changelog

## 2026-11-26 (diagrama animado)

- Nuevo `docs/architecture.gif`, generado a partir de `terraform/` y `ansible/` con iconos oficiales de AWS: el recorrido de una petición se ilumina salto a salto con flechas animadas. Reemplaza a los diagramas PNG anteriores.

## 2026-11-25 (zonas al azar y README)

- Las dos AZ se sortean al azar entre las que están activas y ofrecen `t3.micro` (`aws_ec2_instance_type_offerings`), en lugar de excluir `us-east-1e` a mano.
- Los frontends se reparten entre `public` y `public-2`: si cae una zona, el ALB sigue teniendo destinos.
- El tipo de instancia vive en `local.instance_type` y lo comparten el filtro de zonas y las instancias.
- README ampliado: arquitectura, tecnologías, recorrido de una petición y de la contraseña, uso y limitaciones.
- Cambiar el sorteo reemplaza las subnets; con la infraestructura en pie conviene `terraform destroy` y luego `apply`.

## 2026-11-25 (segundo backend)

- Segundo backend en `private-2` (otra AZ) con `count = 2` y un bloque `moved` para no recrear el existente.
- Caddy reparte `/api/` entre los backends con `round_robin` y reintenta en otro si uno no acepta la conexión.
- La página del frontend consulta `/api/` cada 5 segundos con JavaScript.
- Documentado el workaround de macOS para el lookup de Secrets Manager.

## 2026-11-25 (Ansible)

- Roles `frontend` (Caddy + página con facts y variables mágicas) y `backend` (API Flask con Gunicorn que comprueba MySQL).
- Rol `common` migrado de ntp a chrony con Amazon Time Sync: el paquete `ntp` es solo de transición en Ubuntu 24.04.
- El inventario que genera Terraform ahora tiene grupos `frontend` y `backend`, salto SSH por el primer frontend y los datos de la base.
- Plantilla renombrada de `inventoy.ini.tpl` a `inventory.ini.tpl`.

## 2026-11-25

- Código Terraform inicial: red, seguridad, cómputo, RDS, ALB, secretos e inventario de Ansible.
- Comentarios didácticos en español en todos los archivos `.tf`.
- Comentarios reescritos en español neutro (sin regionalismos de Argentina ni de España).
