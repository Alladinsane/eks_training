#!/bin/bash
# Parameters

project="eks-test"
environment="dev"
region="us-east-1"
profile="default"

function usage {
    echo ""
    echo "Creates the EKS environment specified in RBN training docs."
    echo ""
    echo "usage: create_eks_cluster.sh --name string --vpc_id string"
    echo ""
    echo "  --project string        name to give project"
    echo "  --environment string    (optional)Environment. Default to dev."
    echo "  --vpc_id string         (optional)id of VPC to create cluster in. Must have at least two private subnets"
    echo "  --cluster string        (optional)name of existing EKS cluster to use"
    echo "  --region string         (optional)AWS Region code for resources. Defaults to us-east-1."
    echo "  --profile string        (optional)Named AWS profile to use. Default is default."
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
fi

# Set profile and region
export AWS_PROFILE=$profile
export AWS_REGION=$region
export EKS_ENVIRONMENT=$environment
export project=$project

## Functions
set_pod_execution_role () {
    POD_EXECUTION_ROLE_ARN=$(aws iam get-role --role-name $POD_EXECUTION_ROLE_NAME --query 'Role.Arn' --output text)
}

## Functions
create_pod_execution_role () {
    echo "Creating Pod Execution Role"

    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

    echo $POD_EXECUTION_ROLE_NAME
    POD_EXECUTION_ROLE_ARN=$(aws iam create-role \
        --role-name $POD_EXECUTION_ROLE_NAME \
        --assume-role-policy-document "{ \"Version\": \"2012-10-17\", \"Statement\": [{\"Effect\": \"Allow\", \"Principal\": {\"Service\": \"eks-fargate-pods.amazonaws.com\"}, \"Action\": \"sts:AssumeRole\", \"Condition\": { \"ArnLike\": { \"aws:SourceArn\": [ \"arn:aws:eks:*:$ACCOUNT_ID:fargateprofile/$cluster/*\"]}}}]}" \
        --query 'Role.Arn' --output text) 
    aws iam wait role-exists --role-name $POD_EXECUTION_ROLE_NAME
    aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy --role-name $POD_EXECUTION_ROLE_NAME

    # Arbitrary wait to allow IAM Role to be fully available
    sleep 5
}
## Phase One: Initial Setup

if [[ -z $vpc_id ]]; then
    echo ""
    echo "No vpc_id parameter was provided."
    
    read -p "Create a new vpc for $EKS_ENVIRONMENT-$project? (yes/no) " yn

    case $yn in 
        yes ) echo ...;;
        no ) usage
             die "Please try again and provide the id of a VPC configured for EKS.";;
        * ) echo invalid response;
            exit 1;;
    esac

    echo ""
    echo "Launching a VPC with subnets(including the minimum 2 private), internet gateway, NAT gateways, and route "
    echo "tables required for a basic EKS ready network, using AWS sample template:"
    echo "https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml"
    echo ""
    echo "This may take several minutes..."

    vpc_id=$(./create_eks_vpc.sh )

    echo ""
    echo "Created VPC with id: $vpc_id"
fi

PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
    --filters Name=vpc-id,Values=$vpc_id \
    --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' \
    --output text | sed -E 's/\s+/,/g')

echo $PRIVATE_SUBNETS

if [[ -z $cluster ]]; then
    echo ""
    echo "No cluster parameter was provided."
    
    echo ""
    echo "Creating new EKS cluster in $vpc_id..."

    cluster=$(./create_eks_cluster.sh --private_subnets $PRIVATE_SUBNETS)

    echo ""
    echo "Waiting for $cluster to become available. This will take a while..."
    aws eks wait cluster-active --name $cluster
fi
POD_EXECUTION_ROLE_NAME="$environment-$project-pod-execution-role"
set_pod_execution_role || create_pod_execution_role

echo "Creating fargate profile on $cluster...."
./create_fargate_profile.sh --namespaces default,system --private_subnets $PRIVATE_SUBNETS --execution_role_arn $POD_EXECUTION_ROLE_ARN --cluster $cluster 

echo "Creating and Open Id Identity Provider..."
./create_oidc_provider.sh --cluster $cluster

./update_coredns.sh --private_subnets $PRIVATE_SUBNETS --cluster $cluster --execution_role_arn $POD_EXECUTION_ROLE_ARN --private_subnets $PRIVATE_SUBNETS