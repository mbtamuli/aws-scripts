#!/usr/bin/env bash

# Declare this. Otherwise will use a t2.micro
# INSTANCE_TYPE=

echo -e "[\e[0;34mNOTICE\e[0m] Creating security group"
# Create a security group
groupID="$(aws ec2 create-security-group --group-name gitlab_sg --description 'security group for gitlab')"
aws ec2 authorize-security-group-ingress --group-name gitlab_sg --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name gitlab_sg --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name gitlab_sg --protocol tcp --port 5555 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name gitlab_sg --protocol tcp --port 443 --cidr 0.0.0.0/0

echo -e "[\e[0;34mNOTICE\e[0m] Creating main Gitlab Instance"
instance_id_main="$(aws ec2 run-instances \
	--image-id "${AMI_ID-ami-37743c5d}" \
	--security-groups "gitlab_sg" \
	--count "1" \
	--instance-type "${INSTANCE_TYPE-t2.micro}" \
	--key-name "mbt-test" \
	--query 'Instances[0].InstanceId' \
	--output text)"

public_ip_main="$(aws ec2 describe-instances \
	--instance-id "$instance_id_main" \
	--query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[*].Association.PublicIp'\
	--output text)"

public_dns_main="$(aws ec2 describe-instances \
	--instance-id "$instance_id_main" \
	--query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[*].Association.PublicDnsName'\
	--output text)"

echo -e "[\e[0;34mNOTICE\e[0m] Initializing Gitlab"

echo -e "[\e[0;34mNOTICE\e[0m] Setting Gitlab hostname to $public_dns_main"
sed -i "s/^GITLAB_HOSTNAME=.*/GITLAB_HOSTNAME=$public_dns_main/" start_gitlab.sh
ssh -o StrictHostKeyChecking=no -i mbt-test.pem ubuntu@"$public_ip_main" 'bash -s' < start_gitlab.sh

echo -e "[\e[0;34mNOTICE\e[0m] Creating Gitlab Runner Instance"
instance_id_runner="$(aws ec2 run-instances \
	--image-id "${AMI_ID-ami-37743c5d}" \
	--security-groups "gitlab_sg" \
  --user-data file://start_gitlab_runner.sh \
	--count "1" \
	--instance-type "${INSTANCE_TYPE-t2.micro}" \
	--key-name "mbt-test" \
	--query 'Instances[0].InstanceId' \
	--output text)"

echo -e "[\e[0;34mNOTICE\e[0m] Initializing Gitlab Runner"

public_ip_runner="$(aws ec2 describe-instances \
	--instance-id "$instance_id_runner" \
	--query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[*].Association.PublicIp'\
	--output text)"



echo -e "[\e[0;34mNOTICE\e[0m] Gitlab Instance ID: $instance_id_main"
echo -e "[\e[0;34mNOTICE\e[0m] Gitlab Public IP:   $public_ip_main"
echo -e "[\e[0;34mNOTICE\e[0m] Gitlab Public DNS:   $public_dns_main"
echo -e "[\e[4;31mACTION\e[0m] You can now login using \`ssh -i mbt-test.pem ubuntu@$public_ip_main\`"

echo -e "[\e[0;34mNOTICE\e[0m] Gitlab Runner Instance ID: $instance_id_runner"
echo -e "[\e[0;34mNOTICE\e[0m] Gitlab Runner Public IP:   $public_ip_runner"
echo -e "[\e[4;31mACTION\e[0m] You can now login using \`ssh -i $KEY_NAME.pem ubuntu@$public_ip_runner\`"
