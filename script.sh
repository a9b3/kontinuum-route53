#!/usr/bin/env bash
usage() {
cat << EOF
required
./script.sh --name <name> --root <root>

OPTIONS:
  -h              help

REQUIRED OPTIONS:
  --name          subdomain name eg. foo.example.com
  --root          root domain eg. example.com
EOF
}

# check if awscli and jq are installed
hash aws 2>/dev/null || { echo >&2 "Require aws-cli to be installed run pip install awscli"; exit 1; }
hash jq 2>/dev/null || { echo >&2 "Require jq"; exit 1; }

# get variables from command line flags
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --root*)
      shift
      root=$1
      shift
      ;;
    --name*)
      shift
      name=$1
      shift
      ;;
    *)
      break
      ;;
  esac
done

source=$1

# Check if required args are passed in
if [[ -z $name ]] || [[ -z $root ]]; then
  usage
  exit 1
fi

lazy_create_root_hosted_zones() {
  root=$1

  hosted_zone_exists="$(aws route53 list-hosted-zones | jq -r '.HostedZones[] | select(.Name=="'$root'.")')"
  # early return if hosted zone already exists
  [[ ! -z $hosted_zone_exists ]] && return

  aws route53 create-hosted-zone --name $root. --caller-reference $root
}

upsert_resource_record_sets() {
  name=$1
  hosted_zone_id=$2

  # IMPORTANT: HostedZoneId for the alias target has to be the same as the s3
  # bucket, refer to link below
  #
  # http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region
  #
  # also, it cannot be retreived via cli SMH
  # https://forums.aws.amazon.com/thread.jspa?threadID=116724
  alias_target_dns_name=s3-website-us-west-2.amazonaws.com.
  alias_target_hosted_zone_id=Z3BJ6K6RIION7M

  aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch "$(echo '{
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "AliasTarget": {
            "HostedZoneId": "<hosted_zone_id>",
            "DNSName": "<dns_name>",
            "EvaluateTargetHealth": false
          },
          "Name": "<name>",
          "Type": "A"
        }
      }
    ],
    "Comment": "Creating an alias for <name>"
  }' | sed \
    -e "s/<name>/$name./g" \
    -e "s/<dns_name>/$alias_target_dns_name/g" \
    -e "s/<hosted_zone_id>/$alias_target_hosted_zone_id/g")"
}

lazy_create_root_hosted_zones $root

hosted_zone_id="$(aws route53 list-hosted-zones \
  | jq -r '.HostedZones[] | select(.Name=="'$root'.") | .Id')"

upsert_resource_record_sets $name $hosted_zone_id
