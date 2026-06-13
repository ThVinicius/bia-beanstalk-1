# Criação do Security Group das instâncias do Beanstalk
resource "aws_security_group" "beanstalk_ec2_sg" {
  name        = "beanstalk-ec2-sg"
  description = "Security Group customizado para as instancias EC2 do Beanstalk"
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}