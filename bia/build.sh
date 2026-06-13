versao=$(git rev-parse HEAD | cut -c 1-7)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 633740007402.dkr.ecr.us-east-1.amazonaws.com
docker build -t bia-beanstalk .
docker tag bia-beanstalk:latest 633740007402.dkr.ecr.us-east-1.amazonaws.com/bia-beanstalk:$versao
docker push 633740007402.dkr.ecr.us-east-1.amazonaws.com/bia-beanstalk:$versao