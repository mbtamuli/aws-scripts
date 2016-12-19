#!/bin/bash
#************************************************#
#            start-one-instance.sh               #
#           written by Mriyam Tamuli             #
#                 Dec 16, 2016                   #
#                                                #
#      Create new security groups and a key      #
#        and finally create a new instance       #
#************************************************#

if [[ -f start-one-instance.env ]]; then
  source start-one-instance.env
fi

group_id="";
function create_security_group() {
  local SECURITY_GROUP_NAME="$1"; local SECURITY_GROUP_DESC="$2"
  if [[ -z "${SECURITY_GROUP_DESC// }" ]]; then
    # If description not declared, create a unique SG description.
    SECURITY_GROUP_DESC="SecurityGroup$(date "+%Y%m%d%H%M%S")"
  fi
  group_id="$(aws ec2 create-security-group \
              --group-name "$SECURITY_GROUP_NAME" \
              --description "$SECURITY_GROUP_DESC" \
              --output text)"
}

if [[ -n "${SECURITY_GROUP_NAME// }" ]]; then
  # If SG name is declared in the config, check if it exists in AWS.
  $(aws ec2 describe-security-groups \
             --group-names "$SECURITY_GROUP_NAME" \
             --query 'SecurityGroups[*].GroupName' \
             --output text > /dev/null 2>&1)
  status="$?"
  if [[ "$status" -ne 0 ]]; then
    # It doesn't exist in AWS. So create it.
    echo -e "[\e[0;34mNOTICE\e[0m] Creating new security group"
    create_security_group "$SECURITY_GROUP_NAME" "$SECURITY_GROUP_DESC"
    echo -e "[\e[0;34mNOTICE\e[0m] Creating new security group inbound rules"
    aws ec2 authorize-security-group-ingress --group-name "$SECURITY_GROUP_NAME" --protocol tcp --port 22 --cidr 0.0.0.0/0
  fi
else
  # If SG name is not declared in the config, create a unique SG NAME.
  SECURITY_GROUP_NAME="${`date "+%Y%m%d%H%M%S"`sg}"

  # Create new Security Group
  echo -e "[\e[0;34mNOTICE\e[0m] Creating new security group"
  create_security_group "$SECURITY_GROUP_NAME" "$SECURITY_GROUP_DESC"
  echo -e "[\e[0;34mNOTICE\e[0m] Creating new security group inbound rules"
  aws ec2 authorize-security-group-ingress --group-name "$SECURITY_GROUP_NAME" --protocol tcp --port 22 --cidr 0.0.0.0/0
fi


if [[ -n "${KEY_NAME// }" ]]; then
  # If Key name is declared in the config, check if it exists in AWS.
  $(aws ec2 describe-key-pairs --key-name "$KEY_NAME" > /dev/null 2>&1)
  status="$?"
  if [[ "$status" -ne 0 ]]; then
    # It doesn't exist in AWS. So create it.
    if [[ -z "PUBLIC_KEY" ]]; then
      echo -e "[\e[0;34mNOTICE\e[0m] Creating new key pair"
      aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$new_key_name".pem
      chmod 400 "$new_key_name".pem
    else
      # Will use existing key specified in config
      echo -e "[\e[0;34mNOTICE\e[0m] Importing key pair"
      aws ec2 import-key-pair --key-name "$KEY_NAME" --public-key-material "$PUBLIC_KEY" > /dev/null 2>&1
    fi
  else
    echo -e "[\e[0;34mNOTICE\e[0m] Using existing key"
  fi
else
  # If Key name is not declared in the config, create a unique Key name.
  KEY_NAME="$(date "+%Y%m%d%H%M%S")key"
  # Will create new key
  echo -e "[\e[0;34mNOTICE\e[0m] Creating new key pair"
  aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_NAME".pem
  chmod 400 "$KEY_NAME".pem
fi

# Create instance and display instance id
# Will use default AMI id for Ubuntu Server 16.04
echo -e "[\e[0;34mNOTICE\e[0m] Creating instance"
instance_id="$(aws ec2 run-instances \
	--image-id "${AMI_ID-ami-40d28157}" \
	--security-groups "$SECURITY_GROUP_NAME" \
	--count "${COUNT-1}" \
	--instance-type "${INSTANCE_TYPE-t2.micro}" \
	--key-name "$KEY_NAME" \
	--query 'Instances[0].InstanceId' \
	--output text)"

public_ip="$(aws ec2 describe-instances \
	--instance-id "$instance_id" \
	--query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[*].Association.PublicIp'\
	--output text)"

echo -e "[\e[0;34mNOTICE\e[0m] Instance ID: $instance_id"
echo -e "[\e[0;34mNOTICE\e[0m] Public IP:   $public_ip"
echo -e "[\e[4;31mACTION\e[0m] You can now login using \`ssh -i $KEY_NAME.pem ubuntu@$public_ip\`"
