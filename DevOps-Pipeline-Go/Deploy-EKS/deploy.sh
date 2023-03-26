#!/bin/bash

# Variables

namespace="go-survey"
image_name="triple3a/gosurvey"

# Set the file name and search string
filename="k8s/deployment-app.yml"
searchstring="triple3a/gosurvey:v1"

# Get the tag from Docker Hub
tag=$(curl -s https://hub.docker.com/v2/repositories/triple3a/gosurvey/tags\?page_size\=1000 | jq -r '.results[].name' | awk 'NR==1 {print$1}')

# Extract the numeric part of the tag (assuming it is at the end)
numeric_part=$(echo "$tag" | sed 's/.*\([0-9]\+\)$/\1/')

# Increment the numeric part
next_numeric=$((numeric_part + 1))

# Replace the numeric part in the tag
newtag=$(echo "$tag" | sed "s/$numeric_part$/$next_numeric/")

# End Variables

# Create the cluster
echo "--------------------Creating EKS--------------------"
eksctl create cluster --name cluster1 --region eu-central-1 --nodes-min=2

# remove preious docker images
echo "--------------------Remove Previous build--------------------"
docker rmi -f $(docker images -q $image_name)

# build new docker image with new tag
echo "--------------------Build new Image--------------------"
docker build -t $image_name:$newtag ./Go-app/

# push the latest build to dockerhub
echo "--------------------Pushing Docker Image--------------------"
docker push $image_name:$newtag

# Replace the tag in the kubernetes deployment file
echo "--------------------Update Img Tag--------------------"
awk -v search="$searchstring" -v replace="triple3a/gosurvey:$newtag" '{gsub(search, replace)}1' "$filename" > tmpfile && mv tmpfile "$filename"

# Update kubeconfig
echo "--------------------Update Kubeconfig--------------------"
aws eks update-kubeconfig --name cluster1 --region eu-central-1

# create namespace
echo "--------------------creating Namespace--------------------"
kubectl create ns $namespace || true

# deploy app
echo "--------------------Deploy App--------------------"
kubectl apply -f k8s
