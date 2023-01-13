#!/bin/bash

# Creates a VPC for EKS using the default getting started template from AWS. Wait for stack to finish creating, 
# returns the Id of the newly created VPC

# Recreates step one of Create Your Cluster in https://docs.aws.amazon.com/eks/latest/userguide/getting-started-console.html

function usage {
    echo ""
    echo "Deploys an EKS-ready VPC(using AWS provided cfn template)."
    echo ""
    echo "usage: create_eks_vpc.sh"
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

stack_name="$EKS_ENVIRONMENT-$project-vpc-stack"

aws cloudformation create-stack \
    --stack-name $stack_name \
    --template-url https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml \
    > /dev/null
aws cloudformation wait stack-create-complete --stack-name $stack_name

# Return the vpc id.
echo $(aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" --output text)