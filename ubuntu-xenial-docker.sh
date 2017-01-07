#!/usr/bin/env bash

# Declare this. Otherwise will use Ubuntu 16.04
# AMI_ID=
# Declare this. Otherwise will use a t2.micro
# INSTANCE_TYPE=

echo -e "[\e[0;34mNOTICE\e[0m] Creating security group"
# Create a security group
groupID="$(aws ec2 create-security-group --group-name docker_sg --description 'security group for docker')"
aws ec2 authorize-security-group-ingress --group-name docker_sg --protocol tcp --port 22 --cidr 0.0.0.0/0


cat > install_docker.sh << EOF
#cloud-config
runcmd:
 - '\wget -qO- "https://get.docker.com/" | bash -s'
EOF

echo -e "[\e[0;34mNOTICE\e[0m] Creating Ubuntu 16.04 Instance with docker"
instance_id_main="$(aws ec2 run-instances \
	--image-id "${AMI_ID-ami-40d28157}" \
	--security-groups "docker_sg" \
	--user-data file://install_docker.sh \
	--count "1" \
	--instance-type "${INSTANCE_TYPE-t2.micro}" \
	--key-name "mbt-test" \
	--query 'Instances[0].InstanceId' \
	--output text)"

public_ip_main="$(aws ec2 describe-instances \
	--instance-id "$instance_id_main" \
	--query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[*].Association.PublicIp'\
	--output text)"

printf "[\e[0;34mNOTICE\e[0m] Gitlab Instance ID: $instance_id_main\n"
printf "[\e[0;34mNOTICE\e[0m] Gitlab Public IP:   $public_ip_main\n"
printf "[\e[4;31mACTION\e[0m] You can now login using \`ssh -i mbt-test.pem ubuntu@$public_ip_main\`\n"
