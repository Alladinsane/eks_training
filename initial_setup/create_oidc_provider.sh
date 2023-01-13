#!/bin/bash

# Obtains the OIDC thumbprint for the given cluster and creates an IDP for the cluster

function usage {
    echo ""
    echo "Creates an IDP for Open Id Connect on EKS."
    echo ""
    echo "usage: create_oidc_provider.sh --cluster string"
    echo ""
    echo "  --cluster string        name of ecs cluster to use."
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
fi

# Describe the EKS cluster in order to obtain the OIDC url and domain
endpoint=$(aws eks describe-cluster --name $cluster --query 'cluster.[identity.oidc.issuer]' --output text)
oidc_domain=$(echo $endpoint | awk -F/ '{print $3}')

# Fetch fingerprints for all the certs for the OIDC domain
SHA1_string=$(echo "" | openssl s_client -showcerts -connect $oidc_domain:443 2>&1 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p;/-END CERTIFICATE-/a\\x0' | sed -e '$ d' | xargs -0rl -I% sh -c "echo '%' | openssl x509 -subject -issuer -fingerprint -noout" | tail -1)

# Grab last fingerprint(i.e. top level CA), trim and split so we have only the hash with no colons
IFS="=" read -a string_array <<< $SHA1_string
thumbprint=$(echo ${string_array[-1]} | sed s/://g)

oidc_arn=$(aws iam create-open-id-connect-provider --url $endpoint --thumbprint-list $thumbprint --client-id-list 'sts.amazon.com' --query 'OpenIDConnectProviderArn') 