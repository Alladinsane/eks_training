#!/bin/bash

function usage {
    echo ""
    echo "Deploys an EKS cluster."
    echo ""
    echo "usage: create_eks_cluster.sh --name string --vpc_id string"
    echo ""
    echo "  --project string                 name to give cluster"
    echo "  --private_subnets string         ids of private subnets for the cluster"
    echo
}

function die {
    printf "Script failed: %s\n\n" "$1"
    exit 1
}

while [ $# -gt 0 ]; do
    if [[ $1 == "--help" ]]; then
        usage
        exit 0
    elif [[ $1 == "--"* ]]; then
        v="${1/--/}"
        declare "$v"="$2"
        shift
    fi
    shift
done

if [[ -z $project ]]; then
    usage
    die "Missing parameter --project"
elif [[ -z $private_subnets ]]; then
    usage
    die "Missing parameter --vpc_id"
fi



# Create a Cluster Iam Role and attach the aws managed policy
# https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html - Create Your Cluster steps 2b and 2c

CLUSTER_ROLE_ARN=$(aws iam create-role \
    --role-name $EKS_ENVIRONMENT-$project-cluster-role \
    --assume-role-policy-document "{ \"Version\": \"2012-10-17\", \"Statement\": [{ \"Effect\": \"Allow\", \"Principal\": { \"Service\": \"eks.amazonaws.com\" }, \"Action\": \"sts:AssumeRole\" }]}" \
    --query 'Role.Arn' --output text)

aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
    --role-name $EKS_ENVIRONMENT-$project-cluster-role \
    > /dev/null

# Recreates steps 3 thru 8 of "Create Your Cluster" from AWS Getting Started With EKS,
# which covers creating the cluster in the console

cluster=$(aws eks create-cluster \
    --name $EKS_ENVIRONMENT-$project-cluster \
    --role-arn $CLUSTER_ROLE_ARN \
    --resources-vpc-config subnetIds=$private_subnets \
    --query 'cluster.name' \
    --kubernetes-version 1.24 \
    --output text)

echo $cluster