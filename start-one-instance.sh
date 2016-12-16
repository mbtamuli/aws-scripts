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

group_name="${SECURITY_GROUP_NAME-`date "+%Y%m%d%H%M%S"`sg}"
group_desc="${SECURITY_GROUP_DESC-SecurityGroup`date "+%Y%m%d%H%M%S"`}"
new_key_name="${KEY_NAME-`date "+%Y%m%d%H%M%S"`key}"

echo -e "[\e[0;34mNOTICE\e[0m] Creating new security group"
group_id="$(aws ec2 create-security-group --group-name "$group_name" --description "$group_desc" --output text)"
echo -e "[\e[0;34mNOTICE\e[0m] Creating new security group inbound rules"
aws ec2 authorize-security-group-ingress --group-name "$group_name" --protocol tcp --port 22 --cidr 0.0.0.0/0
if [[ -z "$PUBLIC_KEY" ]]; then
  # Will create new key
  echo -e "[\e[0;34mNOTICE\e[0m] Creating new key pair"
  aws ec2 create-key-pair --key-name "$new_key_name" --query 'KeyMaterial' --output text > "$new_key_name".pem
  chmod 400 "$new_key_name".pem
else
  # Will use existing key
  echo -e "[\e[0;34mNOTICE\e[0m] Importing key pair"
  aws ec2 import-key-pair --key-name "$new_key_name" --public-key-material "$PUBLIC_KEY"
fi

# Create instance and display instance id
# Will use default AMI id for Ubuntu Server 16.04
echo -e "[\e[0;34mNOTICE\e[0m] Creating instance"
instance_id=$(aws ec2 run-instances \
	--image-id "${AMI_ID-ami-40d28157}" \
	--security-group-ids "$group_id" \
	--count "${COUNT-1}" \
	--instance-type "${INSTANCE_TYPE-t2.micro}" \
	--key-name "$new_key_name" \
	--query 'Instances[0].InstanceId' \
	--output text)

public_ip="$(aws ec2 describe-instances \
	--instance-id "$instance_id" \
	--query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[*].Association.PublicIp'\
	--output text)"

echo -e "[\e[0;34mNOTICE\e[0m] Instance ID: $instance_id"
echo -e "[\e[0;34mNOTICE\e[0m] Public IP:   $public_ip"
echo -e "[\e[4;31mACTION\e[0m] You can now login using \`ssh -i $new_key_name ubuntu@$public_ip\`"
