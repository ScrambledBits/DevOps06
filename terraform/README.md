# Que vamos a construir

- VPC
  - Subnet Publica
    - EC2 / Frontend
      - SG
        - Port 80
        - Port 443
        - Port 22
        - Port 5000 a Backend
      - SSH
  - Subnet Privada
    - EC2 / Backend
      - SG
        - Port 22 *
        - Port 3306
      - SSH
    - DB
- Bucket S3
