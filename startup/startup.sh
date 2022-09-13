#!/bin/bash


exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/ubuntu/startup/startup.log 2>&1


aws configure set aws_access_key_id $(curl -s http://metadata.udf/cloudAccounts | jq -r .cloudAccounts[0].apiKey)
aws configure set aws_secret_access_key $(curl -s http://metadata.udf/cloudAccounts | jq -r .cloudAccounts[0].apiSecret)

AWS_ACCOUNT_ID=$(curl -s http://metadata.udf/cloudAccounts | jq -r .cloudAccounts[0].accountId)

echo "export AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID" | sudo tee /etc/profile.d/custom_env.sh

if test ! -f "/home/ubuntu/startup/tracked_account/$AWS_ACCOUNT_ID"; then

  touch /home/ubuntu/startup/tracked_account/$AWS_ACCOUNT_ID

  aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com

  aws ecr create-repository --repository-name nginx-plus-ingress --region eu-central-1
  aws ecr create-repository --repository-name arcadia-microgateway --region eu-central-1

  aws ecr create-repository --repository-name nginx-mesh-metrics --region eu-central-1
  aws ecr create-repository --repository-name nginx-mesh-api --region eu-central-1
  aws ecr create-repository --repository-name nginx-mesh-sidecar --region eu-central-1
  aws ecr create-repository --repository-name nginx-mesh-init --region eu-central-1


  docker tag sorinboiaf5/nginx-mesh-metrics:0.9.0 $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/nginx-mesh-metrics:0.9.0
  docker tag sorinboiaf5/nginx-mesh-api:0.9.0 $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/nginx-mesh-api:0.9.0
  docker tag sorinboiaf5/nginx-mesh-sidecar:0.9.0 $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/nginx-mesh-sidecar:0.9.0
  docker tag sorinboiaf5/nginx-mesh-init:0.9.0 $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/nginx-mesh-init:0.9.0

  docker push $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/nginx-mesh-metrics:0.9.0
  docker push $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/nginx-mesh-api:0.9.0
  docker push $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/nginx-mesh-sidecar:0.9.0
  docker push $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/nginx-mesh-init:0.9.0



  docker tag sorinboia/nginx-plus-ingress:1.11.1 $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/nginx-plus-ingress:1.11.1
  docker tag sorinboiaf5/arcadia-microgateway:apim3.19.4 $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/arcadia-microgateway:v1

  docker push $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/nginx-plus-ingress:1.11.1
  docker push $AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/arcadia-microgateway:v1


  rm -rf /home/ubuntu/lab
  git clone https://github.com/sorinboia/nginx-experience-aws-ac2.0.git /home/ubuntu/lab

  cd /home/ubuntu/lab
  git checkout udf

  find /home/ubuntu/lab/files/  -type f -name "*" -print0 | xargs -0 sed -i "s/DOCKER_REGISTRY/$AWS_ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com/g"

  cd /home/ubuntu/lab/terraform

  terraform init
  terraform plan
  terraform apply --auto-approve
  terraform apply --auto-approve

  mkdir /home/ubuntu/.kube/
  terraform output > /home/ubuntu/.kube/config

 echo "ALL IS DONE"

else

  echo "We just did a reboot"

fi
