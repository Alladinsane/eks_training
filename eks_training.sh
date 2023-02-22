#!/bin/bash 
set -e

project="eks-test"
environment="dev"
region="us-east-1"
profile="default"

workdir=$(pwd)

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

args="--project $project"

if ! [[ -z $vpc_id ]]; then
    args+=" --vpc_id $vpc_id"
fi

if ! [[ -z $cluster ]]; then
    args+=" --cluster $cluster"
fi

if ! [[ -z $region ]]; then
    args+=" --region $region"
fi

if ! [[ -z $profile ]]; then
    args+=" --profile $profile"
fi

if [[ -z $environment ]]; then
    args+=" --environment dev"
else
    args+=" --environment $environment"
fi

# Initial Setup
echo "Initial Setup:"
cd $workdir/initial_setup
./main.sh $args