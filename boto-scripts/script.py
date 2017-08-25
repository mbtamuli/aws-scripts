import boto3
import collections
import datetime
import sys
from pprint import pprint

ec = boto3.client('ec2')
retention_days = 7
reservations = ec.describe_instances(
    Filters=[
            {'Name': 'tag-key', 'Values': ['backup', 'Backup']},
        ]
)
pprint (reservations['Reservations'][0])
# for instance in reservations['Reservations']:
#     print (type(instance))
