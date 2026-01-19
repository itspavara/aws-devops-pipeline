import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm = boto3.client('ssm')

# Your EC2 instance ID
INSTANCE_ID = 'i-09be9cea5ae24cd1f'

def lambda_handler(event, context):
    # Get the uploaded file details
    bucket = event['Records'][0]['s3']['bucket']['name']
    file_key = event['Records'][0]['s3']['object']['key']
    
    logger.info(f"New file uploaded: {file_key}")
    
    # Commands to run on EC2
    commands = [
        # Download from S3
        f'aws s3 cp s3://{bucket}/{file_key} /tmp/app.zip',
        
        # Extract files
        'cd /tmp && unzip -o app.zip',
        
        # Stop services
        'sudo systemctl stop httpd || true',
        'sudo systemctl stop tomcat || true',
        'sleep 3',
        
        # Clean old deployments
        'sudo rm -rf /var/lib/tomcat/webapps/web-project',
        'sudo rm -f /var/lib/tomcat/webapps/web-project.war',
        
        # Deploy new WAR file
        'sudo cp /tmp/target/*.war /var/lib/tomcat/webapps/web-project.war',
        
        # Run install script
        'sudo bash /tmp/scripts/install_dependencies.sh',
        
        # Start services
        'sudo bash /tmp/scripts/start_server.sh',
        
        # Clean up
        'rm -rf /tmp/app.zip /tmp/target /tmp/scripts'
    ]
    
    # Send commands to EC2
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