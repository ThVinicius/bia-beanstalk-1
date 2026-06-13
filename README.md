# BIA Application — Infraestrutura e Guia de Deploy

Este repositório contém o código fonte da aplicação **BIA**, as definições de infraestrutura como código (IaC) utilizando Terraform e os scripts automatizados em Bash para execução do processo de compilação (build) e deploy contínuo no ambiente **AWS Elastic Beanstalk**.

---

## 1. Arquitetura da Infraestrutura na AWS

A pasta `/infra` armazena os arquivos do Terraform responsáveis por provisionar de forma resiliente e isolada os seguintes recursos:

* **AWS Elastic Beanstalk (Docker Platform):** Orquestra o container Docker da aplicação a partir de um arquivo descritivo `docker-compose.yml`.
* **Amazon RDS (PostgreSQL):** Instância de banco de dados relacional totalmente gerenciada localizada em subnets privadas.
* **Amazon ECR (Elastic Container Registry):** Registro privado utilizado para o armazenamento das imagens Docker geradas a cada build do projeto.
* **Políticas do IAM & Security Groups:** Permissões granulares configuradas para permitir que o Beanstalk realize a coleta das imagens do ECR de forma nativa e acesse a porta do RDS (`5432`).

---

## 2. Configuração de Variáveis de Ambiente (ENVs)

A aplicação exige um conjunto específico de variáveis para sua correta inicialização e conexão com o banco de dados.

### Variáveis Requeridas

| Variável | Descrição / Origem do Valor | Exemplo de Valor |
| :--- | :--- | :--- |
| `DB_USER` | Usuário administrador do banco de dados | `postgres` |
| `DB_PWD` | Senha segura configurada via Terraform para o RDS | `SuaSenhaSeguraAqui` |
| `DB_PORT` | Porta padrão de conexão do PostgreSQL | `5432` |
| `DB_HOST` | Endpoint do banco gerado automaticamente pelo AWS RDS | `bia-db.xxxxxx.us-east-1.rds.amazonaws.com` |

### Onde Configurar as Variáveis?

1. Em Produção (AWS Elastic Beanstalk):
   As variáveis são repassadas automaticamente da infraestrutura do Terraform para as propriedades do ambiente no Elastic Beanstalk (`aws_elastic_beanstalk_environment`). Caso queira adicionar novas chaves manuais, acesse: Elastic Beanstalk > Environments > Selecione o seu ambiente > Configuration > Bloco Updates, monitoring, and logging (Editar) > Role até Environment properties e insira as chaves.
2. Ambiente Local (Desenvolvimento):
   Para rodar e testar localmente, as variáveis são lidas do arquivo `bia/config/default.json` ou injetadas via terminal ao iniciar a aplicação através do script de execução local.

---

## 3. Guia Passo a Passo: Provisionando a Infraestrutura (Terraform)

Certifique-se de ter o Terraform CLI e o AWS CLI configurados localmente na sua máquina com permissões administrativas válidas via comando `aws configure`.

## Ajuste Prévio do Dockerfile (Importante)

O front-end construído em Vite requer o endereço de comunicação com a API injetado fixamente em tempo de compilação. 

Antes de iniciar o build, abra o arquivo `Dockerfile` e localize a linha responsável pela build do cliente. Substitua a URL de exemplo pelo CNAME ou endereço DNS real gerado pelo Elastic Beanstalk para o seu ambiente:

```dockerfile
# Substitua a URL abaixo pela URL oficial do seu ambiente Beanstalk
RUN cd client && VITE_API_URL="[http://SEU-AMBIENTE.us-east-1.elasticbeanstalk.com](http://SEU-AMBIENTE.us-east-1.elasticbeanstalk.com)" npm run build

### Passo 3.1: Inicializar o Provedor
Navegue até o diretório de infraestrutura e execute a inicialização para baixar os plugins necessários da AWS:
cd infra/
terraform init

### Passo 3.2: Planejamento dos Recursos
Execute o comando de plano para inspecionar quais recursos serão adicionados ou alterados na sua conta da AWS antes da criação física:
terraform plan

### Passo 3.3: Aplicação e Construção da Infraestrutura
Suba a infraestrutura completa de forma automatizada respondendo sim ou usando a flag de aprovação automática:
terraform apply -auto-approve

*Nota importante:* Este passo específico pode levar cerca de 5 a 10 minutos para concluir enquanto a AWS fornece fisicamente as subnets de rede, as instâncias EC2 do Beanstalk e provisiona a instância de banco de dados do RDS.

---

## 4. Fluxo de Build e Deploy Automatizado

O processo foi unificado para que, com um único comando na sua máquina, a imagem Docker seja compilada, enviada para o Amazon ECR, e o ambiente do Elastic Beanstalk seja atualizado de forma resiliente.

### Passo 4.1: Atribuir Permissões de Execução
Antes de rodar pela primeira vez, certifique-se de que todos os scripts relevantes possuem permissão de execução no seu ambiente Ubuntu/WSL:
chmod +x ./build.sh
chmod +x ./deploy-beanstalk.sh
chmod +x .platform/hooks/postdeploy/01_run_migrations.sh

### Passo 4.2: Configurar os Parâmetros do seu Ambiente
Abra o arquivo `deploy-beanstalk.sh` e ajuste as variáveis iniciais com os dados gerados pelo seu ecossistema AWS:
REGIAO="us-east-1"
CONTA_ID="633740007402"                   # ID da sua conta AWS (conforme seu ECR)
NOME_APP="nome-do-seu-app-no-beanstalk"  # Definido em application.tf
NOME_ENV="meu-app-prod-env"              # Definido em environment.tf

### Passo 4.3: Executar o Deploy
Para compilar a nova versão e enviá-la ao Elastic Beanstalk, basta executar o script unificado na raiz da pasta `bia`:
./deploy-beanstalk.sh

---

## 5. O que acontece nos bastidores ao rodar o comando?

1. Geração de Tag Única: O script utiliza o Git local para extrair os 7 primeiros caracteres do hash do commit atual (ex: d4bf573). Isso garante rastreabilidade total entre o código armazenado e o container rodando na AWS.
2. Autenticação e Compilação (Build): O script invoca o `./build.sh` que faz o login via `aws ecr get-login-password`, compila a aplicação Node.js (Vite + backend) através do `Dockerfile` e faz o `docker push` da imagem tageada para o repositório privado do ECR.
3. Injeção Dinâmica no Descritor: Utilizando o utilitário `sed`, a tag antiga da imagem dentro do seu `docker-compose.yml` é substituída temporariamente pela nova URI da imagem que acabou de subir para o ECR.
4. Empacotamento do Artefato (ZIP): O script gera um arquivo `.zip` contendo o `docker-compose.yml` modificado e a pasta `.platform/`. A pasta `.platform` vai junta no ZIP para garantir que o Beanstalk execute com sucesso o hook de migração automática do banco de dados (`01_run_migrations.sh`) imediatamente após a subida dos containers.
5. Limpeza e Restauração: O `docker-compose.yml` original é restaurado na sua máquina (limpando modificações locais temporárias no Git) e o arquivo `.zip` local é deletado após o envio com sucesso.
6. Atualização da Aplicação: A AWS CLI cria uma nova versão de aplicação no Elastic Beanstalk (`create-application-version`) e atualiza o ambiente (`update-environment`), iniciando a substituição gradativa e segura dos containers sem gerar indisponibilidade (Rolling Update).