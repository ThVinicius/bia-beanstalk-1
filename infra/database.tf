resource "aws_security_group" "rds_sg" {
  name        = "meu-app-rds-sg"
  description = "Permite acesso ao Postgres a partir do Beanstalk"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.beanstalk_ec2_sg.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instância do PostgreSQL no RDS
resource "aws_db_instance" "postgres" {
  identifier           = "meu-postgres-prod"
  allocated_storage    = 20
  max_allocated_storage = 100
  engine               = "postgres"
  engine_version       = "16"
  instance_class       = "db.t3.micro"
  db_name              = "bia"
  username             = "postgres"
  password             = "sua_senha_super_segura"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot  = true
}