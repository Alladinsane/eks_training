#!/bin/bash
set -e 

function usage {
    echo ""
    echo "Creates a Fargate profile for an EKS cluster."
    echo ""
    echo "usage: create_fargate_profile.sh --project string --cluster string --namespaces string,string --execution_role_arn string --private_subnets string,string"
    echo ""
    echo "  --cluster             string        name of ecs cluster to use."
    echo "  --execution_role_arn  string        ARN for the pod execution role"
    echo "  --namespaces          string,string comma-separated list of namespaces to apply profile to"
    echo "  --private_subnets     string,string comma-separated list of namespaces that will need to update"
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

if [[ -z $namespaces ]]; then
    usage
    die "Missing parameter --namespaces"
elif [[ -z $cluster ]]; then
    usage
    die "Missing parameter --cluster"
elif [[ -z $execution_role_arn ]]; then
    usage
    die "Missing parameter --execution_role_arn"
elif [[ -z $private_subnets ]]; then
    usage
    die "Missing parameter --private_subnets"
fi

IFS="," read -a namespace_array <<< $namespaces

selector_list=()
for namespace in "${namespace_array[@]}"; do
    selector_list+=("\"namespace\"=\"$namespace\" ")
done

echo $selector_list

subnets=$(echo $private_subnets | tr ',' ' ')

aws eks create-fargate-profile \
    --fargate-profile-name $EKS_ENVIRONMENT-$project-fargate-profile \
    --cluster-name $cluster \
    --pod-execution-role-arn $execution_role_arn \
    --subnets $subnets \
    --selector "namespace"="default" "namespace"="system" \
    --no-paginate

echo "Waiting for fargate profile to become active..."
aws eks wait fargate-profile-active --cluster-name $cluster --fargate-profile-name $EKS_ENVIRONMENT-$project-fargate-profile
