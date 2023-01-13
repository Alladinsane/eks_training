#!/bin/bash

function usage {
    echo ""
    echo "Updates coreDns for Fargate."
    echo ""
    echo "usage: create_eks_cluster.sh --name string --vpc_id string"
    echo ""
    echo "  --execution_role_arn  string     ARN for the pod execution role"
    echo "  --cluster             string     EKS cluster to use"
    echo "  --private_subnets     string     comma-separated list of namespaces that will need to update"
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

if [[ -z $cluster ]]; then
    usage
    die "Missing parameter --cluster"
elif [[ -z $execution_role_arn ]]; then
    usage
    die "Missing parameter --execution_role_arn"
elif [[ -z $private_subnets ]]; then
    usage
    die "Missing parameter --private_subnets"
fi

aws eks create-fargate-profile \
    --fargate-profile-name coredns \
    --cluster-name $cluster \
    --pod-execution-role-arn $execution_role_arn \
    --selectors namespace=kube-system,labels={k8s-app=kube-dns} \
    --subnets $private_subnets

kubectl patch deployment coredns \
    -n kube-system \
    --type json \
    -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
