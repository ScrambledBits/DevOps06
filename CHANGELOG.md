# Changelog

## 2026-11-25 (Ansible)

- Roles `frontend` (Caddy + página con facts y variables mágicas) y `backend` (API Flask con Gunicorn que comprueba MySQL).
- Rol `common` migrado de ntp a chrony con Amazon Time Sync: el paquete `ntp` es solo de transición en Ubuntu 24.04.
- El inventario que genera Terraform ahora tiene grupos `frontend` y `backend`, salto SSH por el primer frontend y los datos de la base.
- Plantilla renombrada de `inventoy.ini.tpl` a `inventory.ini.tpl`.

## 2026-11-25

- Código Terraform inicial: red, seguridad, cómputo, RDS, ALB, secretos e inventario de Ansible.
- Comentarios didácticos en español en todos los archivos `.tf`.
- Comentarios reescritos en español neutro (sin regionalismos de Argentina ni de España).
