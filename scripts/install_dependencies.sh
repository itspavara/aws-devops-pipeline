#!/bin/bash

echo "Installing dependencies..."

# Install Java 8
if ! command -v java &> /dev/null; then
    echo "Installing Java 8..."
    sudo yum install -y java-1.8.0-openjdk-devel
fi

# Install Tomcat
if ! systemctl list-unit-files | grep -q tomcat; then
    echo "Installing Tomcat..."
    sudo yum install -y tomcat
fi

# Install Apache httpd
if ! command -v httpd &> /dev/null; then
    echo "Installing Apache httpd..."
    sudo yum install -y httpd
fi

# Enable proxy modules for Apache
echo "Configuring Apache..."
sudo yum install -y mod_proxy mod_proxy_http

# Create Apache config for Tomcat proxy
sudo cat > /etc/httpd/conf.d/tomcat_manager.conf << 'EOF'
<VirtualHost *:80>
  ServerAdmin root@localhost
  ServerName app.nextwork.com
  DefaultType text/html
  
  ProxyRequests off
  ProxyPreserveHost On
  ProxyPass / http://localhost:8080/web-project/
  ProxyPassReverse / http://localhost:8080/web-project/
  
  # Error handling
  ProxyErrorOverride Off
  
  <Proxy *>
    Order deny,allow
    Allow from all
  </Proxy>
</VirtualHost>
EOF

# Create Tomcat directories
sudo mkdir -p /var/lib/tomcat/webapps
sudo chown -R tomcat:tomcat /var/lib/tomcat

# Enable services
sudo systemctl enable tomcat
sudo systemctl enable httpd

echo "Dependencies installed successfully!"