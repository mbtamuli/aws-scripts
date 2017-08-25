#!/usr/bin/env bash

if [ -z "$1" ]; then
		# Declare this. Otherwise will use a t2.micro
		# Gitlab CE recommended is 4GB RAM.
		INSTANCE_TYPE_MAIN=t2.medium
		# Runners2
		INSTANCE_TYPE_RUNNER=t2.medium

		printf "[\e[0;34mNOTICE\e[0m] Creating security group\n"
		# Create a security group
		groupID="$(aws ec2 create-security-group --group-name gitlab_sg --description 'security group for gitlab')"
		aws ec2 authorize-security-group-ingress --group-name gitlab_sg --protocol tcp --port 22 --cidr 0.0.0.0/0
		aws ec2 authorize-security-group-ingress --group-name gitlab_sg --protocol tcp --port 80 --cidr 0.0.0.0/0
		aws ec2 authorize-security-group-ingress --group-name gitlab_sg --protocol tcp --port 5555 --cidr 0.0.0.0/0
		aws ec2 authorize-security-group-ingress --group-name gitlab_sg --protocol tcp --port 443 --cidr 0.0.0.0/0

cat > start_gitlab_main.sh << EOF
#cloud-config
runcmd:
 - '\wget -qO- "https://get.docker.com/" | bash -s'
 - '\fallocate -l 2G /swapfile'
 - '\chmod 600 /swapfile'
 - '\mkswap /swapfile'
 - '\swapon /swapfile'
EOF

		printf "[\e[0;34mNOTICE\e[0m] Creating main Gitlab Instance\n"
		instance_id_main="$(aws ec2 run-instances \
			--image-id "${AMI_ID-ami-37743c5d}" \
			--security-groups "gitlab_sg" \
			--user-data file://start_gitlab_main.sh \
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

		printf "[\e[0;34mNOTICE\e[0m] Initializing Gitlab\n"

cat > start_gitlab_main_docker.sh << EOF
#!/usr/bin/env bash
GITLAB_HOSTNAME=ec2-54-91-87-57.compute-1.amazonaws.com
docker run --detach \
	--hostname "\$GITLAB_HOSTNAME" \
	--publish 443:443 --publish 80:80 --publish 5555:22 \
	--name gitlab \
	--volume /srv/gitlab/config:/etc/gitlab \
	--volume /srv/gitlab/logs:/var/log/gitlab \
	--volume /srv/gitlab/data:/var/opt/gitlab \
	gitlab/gitlab-ce:latest
EOF


		printf "[\e[0;34mNOTICE\e[0m] Setting Gitlab hostname to $public_dns_main\n"
		sed -i "s/^GITLAB_HOSTNAME=.*/GITLAB_HOSTNAME=$public_dns_main/" start_gitlab_main_docker.sh
		ssh -o StrictHostKeyChecking=no -i mbt-test.pem ubuntu@"$public_ip_main" 'bash -s' < start_gitlab_main_docker.sh

cat > start_gitlab_runner.sh << EOF
#cloud-config
runcmd:
 - '\wget -qO- "https://get.docker.com/" | bash -s'
 - 'docker run -d --name gitlab-runner \
   -v /var/run/docker.sock:/var/run/docker.sock \
   -v /srv/gitlab-runner/config:/etc/gitlab-runner \
   gitlab/gitlab-runner:alpine'
EOF

		printf "[\e[0;34mNOTICE\e[0m] Creating Gitlab Runner Instance\n"
		instance_id_runner="$(aws ec2 run-instances \
			--image-id "${AMI_ID-ami-37743c5d}" \
			--security-groups "gitlab_sg" \
		  --user-data file://start_gitlab_runner.sh \
			--count "1" \
			--instance-type "${INSTANCE_TYPE-t2.micro}" \
			--key-name "mbt-test" \
			--query 'Instances[0].InstanceId' \
			--output text)"

		printf "[\e[0;34mNOTICE\e[0m] Initializing Gitlab Runner\n"

		public_ip_runner="$(aws ec2 describe-instances \
			--instance-id "$instance_id_runner" \
			--query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[*].Association.PublicIp'\
			--output text)"


		printf "[\e[0;34mNOTICE\e[0m] Cleaning up\n"
		rm -f	start_gitlab_main.sh start_gitlab_main_docker.sh start_gitlab_runner.sh

		printf "[\e[0;34mNOTICE\e[0m] Gitlab Instance ID: $instance_id_main\n"
		printf "[\e[0;34mNOTICE\e[0m] Gitlab Public IP:   $public_ip_main\n"
		printf "[\e[0;34mNOTICE\e[0m] Gitlab Public DNS:   $public_dns_main\n"
		printf "[\e[4;31mACTION\e[0m] You can now login using \`ssh -i mbt-test.pem ubuntu@$public_ip_main\`\n"

		printf "[\e[0;34mNOTICE\e[0m] Gitlab Runner Instance ID: $instance_id_runner\n"
		printf "[\e[0;34mNOTICE\e[0m] Gitlab Runner Public IP:   $public_ip_runner\n"
		printf "[\e[4;31mACTION\e[0m] You can now login using \`ssh -i mbt-test.pem ubuntu@$public_ip_runner\`\n"

		rm -f .gitlab_with_runners_ids
		touch .gitlab_with_runners_ids
		echo "$instance_id_main" >> .gitlab_with_runners_ids
		echo "$instance_id_runner" >> .gitlab_with_runners_ids

else
	if [[ "$1" == "terminate" ]]; then
		ids=()
		while IFS= read -r instance; do
			ids+=( "$instance" )
		done < .gitlab_with_runners_ids
		printf "[\e[4;31mWARNING\e[0m] TERMINATING Gitlab main and runner EC2 instances\n"
		aws ec2 terminate-instances --instance-ids ${ids[@]}
		printf "[\e[4;34mNOTICE\e[0m] As the instances will take time to completely terminate, "
		printf "[\e[4;34mNOTICE\e[0m] the security groups will be deleted after 5 minutes.\n"
		printf "[\e[4;34mNOTICE\e[0m] Keep this terminal open.\n"
		sleep 300 && \
		printf "[\e[4;31mWARNING\e[0m] TERMINATING Gitlab Security Group\n" && \
		aws ec2 delete-security-group --group-name gitlab_sg &
	fi
fi
