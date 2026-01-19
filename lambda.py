import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm = boto3.client('ssm')

INSTANCE_ID = 'i-09be9cea5ae24cd1f'

def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    file_key = event['Records'][0]['s3']['object']['key']
    
    logger.info(f"New file uploaded: {file_key}")
    
    commands = [
        f'aws s3 cp s3://{bucket}/{file_key} /tmp/app.zip',
        
        'cd /tmp && unzip -o app.zip',
        
        'sudo systemctl stop httpd || true',
        'sudo systemctl stop tomcat || true',
        'sleep 3',
        
        'sudo rm -rf /var/lib/tomcat/webapps/web-project',
        'sudo rm -f /var/lib/tomcat/webapps/web-project.war',
        
        'sudo cp /tmp/target/*.war /var/lib/tomcat/webapps/web-project.war',
        
        'sudo bash /tmp/scripts/install_dependencies.sh',
        
        'sudo bash /tmp/scripts/start_server.sh',
        
        'rm -rf /tmp/app.zip /tmp/target /tmp/scripts'
    ]
    
    response = ssm.send_command(
        InstanceIds=[INSTANCE_ID],
        DocumentName='AWS-RunShellScript',
        Parameters={'commands': commands},
        TimeoutSeconds=600
    )
    
    command_id = response['Command']['CommandId']
    logger.info(f"Deployment started! Command ID: {command_id}")
    
    return {
        'statusCode': 200,
        'body': f'Deployment initiated: {command_id}'
    }