#!/usr/bin/env bash

# TODO Move these to a .env file
autoscale_group_name=my-asg
log_file=autoscaling.log
number_of_days_of_backup_to_keep="+10 minute"

new_name="test-$(date "+%Y%m%d%H%M%S")"
oldest_name="test-$(date -d "$number_of_days_of_backup_to_keep")"

printf '=%.0s' {1..100} >> $log_file
printf "\nRunning for date: $(date "+%Y%m%d%H%M%S")\n" >> $log_file

echo "Checking instance from autoscalling group: ${autoscale_group_name}" >> $log_file

# Get instance ID for AMI creation
instance_id=$(aws autoscaling describe-auto-scaling-instances --output text | grep ${autoscale_group_name} | cut -f5 | head -n1)

echo "Found instance ID: ${instance_id}" >> $log_file

# Check OLD AMI is present or not
aws ec2 describe-images --filters Name=name,Values="${oldest_name}" --output text | grep snap

if [[ "$?" -eq 0 ]]; then
	# Find SnapShot ID and AMI ID to be deleted
	snapshot_id="$(aws ec2 describe-images --filters Name=name,Values=${oldest_name} --output text | grep snap | cut -f4)"
	ami_id="$(aws ec2 describe-images --filters Name=name,Values=${oldest_name} --output text | grep ami | cut -f6)"

	# Check whether that AMI ID is used in launch configuration. If so don't delete that AMI
	launch_config=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name ${autoscale_group_name} | grep LaunchConfigurationName  | awk -F\" '{ print $4 }')
	aws autoscaling describe-launch-configurations --launch-configuration-names ${launch_config} | grep ${ami_id}

	if [[ "$?" -ne 0 ]]; then
		echo "Found Snapshot ID: ${snapshot_id} and AMI ID: ${ami_id}, deleting that" >> $log_file

		# Deregister AMI
		aws ec2 deregister-image --image-id ${ami_id}

		# Delete Snapshot
		aws ec2 delete-snapshot --snapshot-id ${snapshot_id}
	fi
fi

echo "Creating AMI for instance ID: ${instance_id}" >> $log_file

# Create Image for instance ID
new_ami_id="$(aws ec2 create-image --instance-id "${instance_id}" --name "${new_name}" --description "AMI created by Autocreation script" --no-reboot --output text)"

echo "ID of new AMI: $new_ami_id" >> $log_file

new_lc_name="test_lc-$(date "+%Y%m%d%H%M%S")"

echo "Creating new launch config: $new_lc_name"
aws autoscaling create-launch-configuration --launch-configuration-name $new_lc_name --image-id $new_ami_id --instance-type t2.micro --security-groups sg-bb1c35c6 --key-name mbt-test --block-device-mappings "[{\"DeviceName\": \"/dev/sda1\",\"Ebs\":{\"VolumeSize\":8}}]"

echo "Updating autoscalinggroup with new launch config: $new_lc_name"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "my-asg" --launch-configuration-name $new_lc_name
