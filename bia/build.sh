#!/bin/bash

# Interrompe o script se qualquer comando falhar
set -e

# Parâmetros de configuração (Alinhados com o deploy-beanstalk.sh)
REGIAO="us-east-1"
CONTA_ID="633740007402"
NOME_COMPARTILHADO="bia-beanstalk"

# Obter a tag da versão atual (7 primeiros caracteres do hash do git)
versao=$(git rev-parse HEAD | cut -c 1-7)

echo "=== Iniciando Compilação da Imagem Docker ==="

# Autenticação no ECR correspondente às variáveis
aws ecr get-login-password --region "$REGIAO" | docker login --username AWS --password-stdin "${CONTA_ID}.dkr.ecr.${REGIAO}.amazonaws.com"

# Build da imagem local
docker build -t "$NOME_COMPARTILHADO" .

# Tagging da imagem com a versão do commit Git
docker tag "${NOME_COMPARTILHADO}:latest" "${CONTA_ID}.dkr.ecr.${REGIAO}.amazonaws.com/${NOME_COMPARTILHADO}:$versao"

# Push da imagem para o registro privado da AWS
docker push "${CONTA_ID}.dkr.ecr.${REGIAO}.amazonaws.com/${NOME_COMPARTILHADO}:$versao"

echo "=== Imagem Docker enviada ao ECR com sucesso! ==="