import boto3
import collections
import datetime
import sys
from pprint import pprint

ec = boto3.client('ec2')
retention_days = 7
def lambda_handler(event, context):

    reservations = ec.describe_instances(
        Filters=[
            {'Name': 'tag-key', 'Values': ['backup', 'Backup']},
        ]
    ).get(
        'Reservations', []
    )
    print (reservations)

    instances = sum(
        [
            [i for i in r['Instances']]
            for r in reservations

        ], [])

    print "Found %d instances that need backing up" % len(instances)

    to_tag = collections.defaultdict(list)

    for instance in instances:
            name_tag = [
                str(t.get('Value')) for t in instance['Tags']
                if t['Key'] == 'Name'][0]
            print (name_tag)
            print ("check_loop")

            create_time = datetime.datetime.now()
            create_fmt = create_time.strftime('%Y-%m-%d')

            AMIid = ec.create_image(InstanceId=instance['InstanceId'], Name="Lambda - " + instance['InstanceId'] + " " + name_tag +" from " + create_fmt, Description="Lambda created AMI of instance " + instance['InstanceId'] + " " + name_tag + " from " + create_fmt, NoReboot=True, DryRun=False)
            to_tag[retention_days].append(AMIid['ImageId'])

            delete_date = datetime.date.today() + datetime.timedelta(days=retention_days)
            delete_fmt = delete_date.strftime('%m-%d-%Y')

            ec.create_tags(
                Resources=to_tag[retention_days],
                Tags=[
                        {'Key': 'DeleteOn', 'Value': delete_fmt},

                    ]
            )


            print ("Name tag " + name_tag)
            print ("check_loopend")

