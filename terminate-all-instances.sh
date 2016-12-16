#!/bin/bash
#************************************************#
#          terminate-all-instance.sh             #
#           written by Mriyam Tamuli             #
#                 Dec 16, 2016                   #
#                                                #
#           Terminate all instances              #
#************************************************#

LOGFILE="terminate_log_`date '+%Y%m%d%H%M%S'`"

printf "[\e[4;31mWARNING\e[0m] Are you sure you want to terminate all instances(This action is irreversible)? (y/N) "

read choice

if [[ "$choice" == "Y" ]] || [[ "$choice" == "y" ]]; then
  instances_not_terminated="$(aws ec2 describe-instances \
				--filter Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped \
				--query 'Reservations[*].Instances[*].InstanceId' \
				--output text)"

  while IFS= read -r instance; do
    echo -e "[\e[0;34mNOTICE\e[0m] Deleting instance: $instance"
    aws ec2 terminate-instances --instance-ids "$instance" >> $LOGFILE
  done <<< "$instances_not_terminated"

  echo -e "[\e[0;34mNOTICE\e[0m] Check logfile $LOGFILE"
fi
