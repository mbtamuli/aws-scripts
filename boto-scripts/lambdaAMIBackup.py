import boto3
import collections
import datetime
from pprint import pprint

retention_days = 7
ec = boto3.client('ec2')
def lambda_handler(event, context):
    reservations = ec.describe_instances(Filters=[{'Name': 'tag-key', 'Values': ['backup', 'Backup']}])
    print("Found {} instances that need backing up".format(len(reservations['Reservations'])))
    ids = dict()
    create_date = datetime.date.today().isoformat()

    print("Starting AMI creation at {}".format(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S %p")))
    for reservation in reservations['Reservations']:
        for instance in reservation['Instances']:
            ids[instance['InstanceId']] = { tag['Key']: tag['Value'] for tag in instance['Tags'] }
            AMIid = ec.create_image(
                    InstanceId=instance['InstanceId'],
                    Name=ids[instance['InstanceId']]['Name'] + " on " + create_date,
                    Description="Lambda created AMI of instance " + ids[instance['InstanceId']]['Name'] + " on " + create_date,
                    NoReboot=True,
                    DryRun=False
            )

            ids[instance['InstanceId']].update({'AMIid': AMIid['ImageId']})
            delete_date = (datetime.date.today() + datetime.timedelta(days=retention_days)).isoformat()

            ec.create_tags(
                Resources=[AMIid['ImageId']],
                Tags=[
                    {
                        'Key': 'InstanceId',
                        'Value': instance['InstanceId']
                    },
                    {
                        'Key': 'Client',
                        'Value': ids[instance['InstanceId']]['Client']
                    },
                    {
                        'Key': 'DeleteOn',
                        'Value': delete_date
                    },
                ]
            )
    pprint(ids)
    print("AMI creation completed at {}".format(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S %p")))

if __name__ == "__main__":
    lambda_handler(None, None)
