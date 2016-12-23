aws autoscaling create-launch-configuration --launch-configuration-name test-lc --image-id ami-40d28157 --instance-type t2.micro --security-groups sg-bb1c35c6 --key-name mbt-test --block-device-mappings "[{\"DeviceName\": \"/dev/sda1\",\"Ebs\":{\"VolumeSize\":8}}]"

aws autoscaling create-auto-scaling-group --auto-scaling-group-name my-asg --launch-configuration-name test-lc --default-cooldown 60 --max-size 5 --min-size 1 --tags "ResourceId=my-asg,ResourceType=auto-scaling-group,Key=Name,Value=ASG_Instance,PropagateAtLaunch=true" --availability-zones "us-east-1c"

scaleoutARN="$(aws autoscaling put-scaling-policy --policy-name my-scaleout-policy --auto-scaling-group-name my-asg --scaling-adjustment 1 --adjustment-type ChangeInCapacity --cooldown 60 --query 'PolicyARN' --output text)"

scaleinARN="$(aws autoscaling put-scaling-policy --policy-name my-scalein-policy --auto-scaling-group-name my-asg --scaling-adjustment -1 --adjustment-type ChangeInCapacity --cooldown 60 --query 'PolicyARN' --output text)"

aws cloudwatch put-metric-alarm --alarm-name AddCapacity --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 40 --comparison-operator GreaterThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=my-asg" --evaluation-periods 2 --alarm-actions "$scaleoutARN"

aws cloudwatch put-metric-alarm --alarm-name RemoveCapacity --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 20 --comparison-operator LessThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=my-asg" --evaluation-periods 2 --alarm-actions "$scaleinARN"
