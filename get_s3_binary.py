import boto3
import logging
logging.basicConfig(level=logging.DEBUG)

# Assume role to get temporary credentials
sts_client = boto3.client('sts')
assumed_role = sts_client.assume_role(
    RoleArn='arn:aws:s3:::releases.yugabyte.com/ybc/',
    RoleSessionName='AssumeRoleSession'
)

# Use the temporary credentials returned in assumed_role to access the S3 bucket
s3_client = boto3.client('s3',
                         aws_access_key_id=assumed_role['Credentials']['AccessKeyId'],
                         aws_secret_access_key=assumed_role['Credentials']['SecretAccessKey'],
                         aws_session_token=assumed_role['Credentials']['SessionToken'])

# Name of the S3 bucket
bucket_name = 'releases.yugabyte.com'

# List the objects in the bucket
response = s3_client.list_objects(Bucket=bucket_name)

# Print object names
for obj in response['Contents']:
    print(obj['Key'])

