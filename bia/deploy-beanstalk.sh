#!/bin/bash

# Interrompe o script se qualquer comando falhar
set -e

echo "=== Iniciando processo de deploy para o Elastic Beanstalk ==="

# 1. Obter a tag da versão atual (7 primeiros caracteres do hash do git)
VERSAO=$(git rev-parse HEAD | cut -c 1-7)
echo "Versão identificada (Git Commit): $VERSAO"

# 2. Executar o script de build existente para gerar e subir a imagem para o ECR
echo "Executando build e push da imagem Docker..."
chmod +x ./build.sh
./build.sh

# Configurações do Beanstalk e ECR
REGIAO="us-east-1"
CONTA_ID="633740007402"
NOME_APP="bia-app"       
NOME_ENV="meu-app-prod-env"                  
NOME_COMPARTILHADO="bia-beanstalk"

IMAGE_URI="${CONTA_ID}.dkr.ecr.${REGIAO}.amazonaws.com/${NOME_COMPARTILHADO}:${VERSAO}"
ARQUIVO_ZIP="deploy-${VERSAO}.zip"
VERSAO_LABEL="release-${VERSAO}-$(date +%Y%m%d%H%M%S)"
BUCKET_S3="elasticbeanstalk-${REGIAO}-${CONTA_ID}"

echo "Modificando temporariamente o docker-compose.yml com a nova imagem..."

# 3. Modificar a linha da imagem no docker-compose.yml usando sed de forma segura
sed -i.bak -E "s|(image:[[:space:]]*)[^[:space:]]+|\1${IMAGE_URI}|" docker-compose.yml

# 4. Criar o pacote de deploy (ZIP contendo o docker-compose.yml modificado e a pasta .platform)
echo "Criando artefato de deploy: ${ARQUIVO_ZIP}"
zip -r "$ARQUIVO_ZIP" docker-compose.yml .platform

# Restaurar o docker-compose.yml original (com o backup .bak feito pelo sed) para não sujar o Git local
mv docker-compose.yml.bak docker-compose.yml

# 5. Enviar o arquivo ZIP local para o S3 da AWS
echo "Fazendo upload do arquivo ZIP para o S3 (s3://${BUCKET_S3}/${NOME_APP}/${ARQUIVO_ZIP})..."
aws s3 cp "$ARQUIVO_ZIP" "s3://${BUCKET_S3}/${NOME_APP}/${ARQUIVO_ZIP}"

# 6. Registrar a nova versão de aplicação apontando para o arquivo no S3
echo "Registrando a nova versão no Elastic Beanstalk..."
aws elasticbeanstalk create-application-version \
    --application-name "$NOME_APP" \
    --version-label "$VERSAO_LABEL" \
    --source-bundle S3Bucket="$BUCKET_S3",S3Key="${NOME_APP}/${ARQUIVO_ZIP}" \
    --auto-create-application

# 7. Atualizar o ambiente do Beanstalk para implantar a nova versão
echo "Atualizando o ambiente $NOME_ENV para a versão $VERSAO_LABEL..."
aws elasticbeanstalk update-environment \
    --environment-name "$NOME_ENV" \
    --version-label "$VERSAO_LABEL"

# 8. Limpar o arquivo zip local criado
rm -f "$ARQUIVO_ZIP"

echo "=== Deploy solicitado com sucesso! Acompanhe a atualização no console da AWS ==="