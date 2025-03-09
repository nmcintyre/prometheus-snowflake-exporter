#!/bin/bash
set -e

# Configuration - replace these values with your own
ECR_REPO="730335435932.dkr.ecr.us-east-1.amazonaws.com"
IMAGE_NAME="nmcintyre-kafka-on-eks/prometheus-snowflake-exporter"
IMAGE_TAG="latest"
PLATFORM="linux/arm64"

SNOWFLAKE_EXPORTER_ACCOUNT=bub59917.us-east-1
SNOWFLAKE_EXPORTER_USERNAME=PROMETHEUS_USER
SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH=/run/secrets/private-key.p8
SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE=$(cat ./secrets/rsa-key-passphrase.txt)
SNOWFLAKE_EXPORTER_ROLE=PROMETHEUS_ROLE
SNOWFLAKE_EXPORTER_WAREHOUSE=METRICS_WH

# Ensure AWS CLI is configured
echo "Checking AWS CLI configuration..."
aws sts get-caller-identity --no-cli-pager

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $(aws configure get region) --no-cli-pager | docker login --username AWS --password-stdin $ECR_REPO

# Create ECR repository if it doesn't exist
#echo "Creating ECR repository if it doesn't exist..."
#aws ecr describe-repositories --repository-names $IMAGE_NAME || aws ecr create-repository --repository-name $IMAGE_NAME

# Build the Docker image
echo "Building Docker image..."

echo docker buildx build --platform "${PLATFORM}" --build-arg SNOWFLAKE_EXPORTER_ACCOUNT="${SNOWFLAKE_EXPORTER_ACCOUNT}" --build-arg SNOWFLAKE_EXPORTER_USERNAME="${SNOWFLAKE_EXPORTER_USERNAME}" --build-arg SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH="${SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH}" --build-arg SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE="${SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE}" --build-arg SNOWFLAKE_EXPORTER_ROLE="${SNOWFLAKE_EXPORTER_ROLE}" --build-arg SNOWFLAKE_EXPORTER_WAREHOUSE="${SNOWFLAKE_EXPORTER_WAREHOUSE}" -t "${IMAGE_NAME}:${IMAGE_TAG}" . --load
docker buildx build --platform "${PLATFORM}" --build-arg SNOWFLAKE_EXPORTER_ACCOUNT="${SNOWFLAKE_EXPORTER_ACCOUNT}" --build-arg SNOWFLAKE_EXPORTER_USERNAME="${SNOWFLAKE_EXPORTER_USERNAME}" --build-arg SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH="${SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH}" --build-arg SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE="${SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE}" --build-arg SNOWFLAKE_EXPORTER_ROLE="${SNOWFLAKE_EXPORTER_ROLE}" --build-arg SNOWFLAKE_EXPORTER_WAREHOUSE="${SNOWFLAKE_EXPORTER_WAREHOUSE}" -t "${IMAGE_NAME}:${IMAGE_TAG}" . --load
#docker build --build-arg DB_HOST="${DB_HOST}" --build-arg DB_USER="${DB_USER}" --build-arg DB_PASSWORD="${DB_PASSWORD}" --build-arg DB_DATABASE="${DB_DATABASE}" -t $IMAGE_NAME:$IMAGE_TAG .

# Tag the image for ECR
echo "Tagging image for ECR..."
docker tag $IMAGE_NAME:$IMAGE_TAG $ECR_REPO/$IMAGE_NAME:$IMAGE_TAG

#echo "Exiting..."
#exit 0

# Push the image to ECR
echo "Pushing image to ECR..."
docker push $ECR_REPO/$IMAGE_NAME:$IMAGE_TAG

# Update Kubernetes deployment files
#echo "Updating Kubernetes deployment files..."
#sed -i "s|\${YOUR_ECR_REPO}|$ECR_REPO|g" kubernetes/deployment.yaml

# Apply Kubernetes configurations
echo "Applying Kubernetes configurations..."
kubectl apply -f kubernetes/secret.yaml
kubectl apply -f kubernetes/deployment.yaml

echo "Rolling out deployments..."
for deployment in $(kubectl get deployments.apps -l app=cdc-simulator | awk '/cdc-.*-simulator/ {print $1}'); do
    kubectl rollout restart deployment $deployment
done

cat <<EOF
Deployment complete!

To check the status, run: kubectl get pods -n monitoring -l app=prometheus-snowflake-exporter
To view logs,        run: kubectl logs -n monitoring -f deployment/prometheus-snowflake-exporter
EOF
