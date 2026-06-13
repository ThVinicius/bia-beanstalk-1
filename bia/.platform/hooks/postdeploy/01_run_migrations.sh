#!/bin/bash

# 1. Navega até a pasta onde o Beanstalk colocou o docker-compose.yml no host
cd /var/app/current

# 2. Executa o comando de criação DENTRO do container 'server'
# O parâmetro -T é obrigatório para scripts automatizados (desativa o TTY)
echo "=== Tentando criar o banco de dados dentro do container ==="
docker compose exec -T server npx sequelize db:create || echo "Aviso: O banco de dados já existe."

# 3. Executa as migrações DENTRO do container 'server'
echo "=== Executando migrações do banco de dados dentro do container ==="
docker compose exec -T server npx sequelize db:migrate