#!/bin/bash

echo "Starting services..."

# Start Tomcat first
echo "Starting Tomcat..."
sudo systemctl start tomcat

# Wait for Tomcat to fully start and deploy the WAR
echo "Waiting for Tomcat to deploy application..."
sleep 30

# Check if Tomcat is running
if ! sudo systemctl is-active --quiet tomcat; then
    echo "ERROR: Tomcat failed to start"
    sudo journalctl -u tomcat -n 20 --no-pager
    exit 1
fi

echo "Tomcat started successfully!"

# Check if WAR was deployed
WAR_NAME=$(ls /var/lib/tomcat/webapps/*.war 2>/dev/null | head -n 1)
if [ -z "$WAR_NAME" ]; then
    echo "WARNING: No WAR file found!"
else
    echo "Deployed WAR: $WAR_NAME"

    sleep 15
    
    if [ -d "/var/lib/tomcat/webapps/web-project" ]; then
        echo "Application extracted successfully!"
    else
        echo "Checking what was deployed..."
        ls -la /var/lib/tomcat/webapps/
    fi
fi

echo "Testing Tomcat..."
TOMCAT_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/web-project/ || echo "000")
echo "Tomcat response code: $TOMCAT_TEST"

if [ "$TOMCAT_TEST" = "200" ] || [ "$TOMCAT_TEST" = "302" ]; then
    echo "Tomcat is serving the application!"
else
    echo "WARNING: Application may not be ready yet (HTTP $TOMCAT_TEST)"
    echo "Tomcat logs:"
    sudo tail -20 /var/log/tomcat/catalina.out
fi

# Start Apache httpd
echo "Starting Apache httpd..."
sudo systemctl start httpd

sleep 5

# Check if httpd is running
if sudo systemctl is-active --quiet httpd; then
    echo "Apache httpd started successfully!"
else
    echo "ERROR: Apache httpd failed to start"
    sudo journalctl -u httpd -n 20 --no-pager
    exit 1
fi

# Test through Apache
echo "Testing through Apache proxy..."
APACHE_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ || echo "000")
echo "Apache response code: $APACHE_TEST"

echo "=== Deployment Complete ==="
echo "Access your application at:"
echo "  - Direct Tomcat: http://YOUR_EC2_IP:8080/web-project/"
echo "  - Through Apache: http://YOUR_EC2_IP/"