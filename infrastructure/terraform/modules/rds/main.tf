
resource "aws_db_subnet_group" "main" {
  name    = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids
  
  tags = {
    Name    = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
    Project    = var.project_name
  }
}

resource "aws_security_group" "db" {
  name    = "${var.project_name}-${var.environment}-db-sg"
  description = "Security group for RDS instance"
  vpc_id    = var.vpc_id
  
  ingress {
    description    = "PostgreSQL from EKS nodes"
    from_port    = 5432
    to_port    = 5432
    protocol    = "tcp"
    security_groups = [
      var.eks_sg_id,
      "sg-09db02b626965c558",
      "sg-0f14a3750de9dad48"
    ]
  }
  
  egress {
    from_port   = 0
    to_port    = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name    = "${var.project_name}-${var.environment}-db-sg"
    Environment = var.environment
    Project    = var.project_name
  }
}

resource "aws_db_instance" "main" {
  identifier    = "${var.project_name}-${var.environment}-db"
  engine    = "postgres"
  engine_version    = "13.21"  # Zmieniono na 14.8
  instance_class    = "db.t3.micro"
  allocated_storage    = 20
  max_allocated_storage  = 100
  db_name    = var.db_name
  username    = var.db_username
  password    = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
  
  backup_retention_period = 7
  backup_window    = "03:00-04:00"
  maintenance_window    = "sun:04:00-sun:05:00"
  
  tags = {
    Name    = "${var.project_name}-${var.environment}-db"
    Environment = var.environment
    Project    = var.project_name
  }
}


