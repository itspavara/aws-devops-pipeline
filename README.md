# AWS DevOps CI/CD Pipeline 

> **Automated deployment pipeline for Java web applications using AWS services**

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Setup Guide](#setup-guide)
- [Understanding the Pipeline](#understanding-the-pipeline)
- [Configuration Files](#configuration-files)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This project implements a complete CI/CD pipeline that automatically builds, packages, and deploys a Java web application to an EC2 instance whenever code is pushed to GitHub.

### What This Pipeline Does

```
Code Push → GitHub → CodeBuild → S3 → Lambda → EC2 (Tomcat + Apache)
```

1. **Developer pushes code** to GitHub
2. **GitHub webhook** triggers AWS CodeBuild
3. **CodeBuild** compiles Java code and creates WAR file
4. **CodeBuild** uploads artifact (ZIP) to S3 bucket
5. **S3 event** triggers Lambda function
6. **Lambda** sends deployment commands to EC2 via SSM
7. **EC2** downloads, deploys, and starts the application
8. **Application is live** on Apache + Tomcat

### Technologies Used

- **Java 8** (Amazon Corretto)
- **Maven** - Build tool
- **Apache Tomcat** - Application server
- **Apache HTTP Server** - Reverse proxy
- **AWS CodeBuild** - Build automation
- **AWS Lambda** - Deployment orchestration
- **AWS S3** - Artifact storage
- **AWS Systems Manager (SSM)** - Remote command execution
- **AWS IAM** - Security and permissions

---

## 🏗️ Architecture

```
┌─────────────┐
│   GitHub    │
│  Repository │
└──────┬──────┘
       │ Push Code
       ▼
┌─────────────────┐
│  AWS CodeBuild  │
│                 │
│  1. Clone repo  │
│  2. mvn package │
│  3. Create ZIP  │
└────────┬────────┘
         │ Upload Artifact
         ▼
┌─────────────────┐
│   S3 Bucket     │
│  my-app.zip     │
└────────┬────────┘
         │ Trigger Event
         ▼
┌─────────────────┐
│ Lambda Function │
│                 │
│ Send SSM        │
│ Command         │
└────────┬────────┘
         │ Execute Commands
         ▼
┌─────────────────────────────┐
│       EC2 Instance          │
│                             │
│  ┌──────────────────────┐   │
│  │   Apache httpd       │   │
│  │   (Port 80)          │   │
│  └──────────┬───────────┘   │
│             │ Proxy          │
│  ┌──────────▼───────────┐   │
│  │   Apache Tomcat      │   │
│  │   (Port 8080)        │   │
│  │   /web-project/      │   │
│  └──────────────────────┘   │
└─────────────────────────────┘
```

---

## 📦 Prerequisites

### AWS Account Requirements

- Free Tier AWS account
- EC2 instance (t2.micro eligible)
- S3 bucket for artifacts
- IAM permissions to create roles

### Local Development

- Git installed
- Maven 3.x
- Java 8 JDK
- Text editor / IDE

### AWS Services Setup

1. **EC2 Instance** - Amazon Linux 2
2. **CodeBuild Project** - Connected to GitHub
3. **S3 Bucket** - For storing build artifacts
4. **Lambda Function** - For deployment automation
5. **IAM Roles** - For EC2 and Lambda

---

## 📁 Project Structure

```
your-project/
├── README.md
├── pom.xml                          # Maven configuration
├── buildspec.yml                    # CodeBuild instructions
├── webapp.yaml                      # CloudFormation yaml for Production Environment
├── src/
│    |
│    └── webapp/                  # Web resources
│           ├── WEB-INF/
│           │   └── web.xml
│           └── index.jsp
└── scripts/
    ├── install_dependencies.sh      # Install Java, Tomcat, Apache
    └── start_server.sh              # Start services
```

---

## 🚀 Setup Guide

### Step 1: Prepare Your Developmetn Environment EC2 Instance

SSH into your EC2 instance:

```bash
ssh -i your-key.pem ec2-user@your-ec2-ip
```

Install required packages:

```bash
# 1. Install SSM Agent (for remote commands)
sudo yum install -y amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent

# 2. Install AWS CLI (to download from S3)
sudo yum install -y aws-cli

# 3. Install unzip
sudo yum install -y unzip

# 4. Install Java 8
sudo yum install -y java-1.8.0-openjdk-devel

# 5. Install Tomcat
sudo yum install -y tomcat

# 6. Enable Tomcat
sudo systemctl enable tomcat

# 7. Verify installations
systemctl status amazon-ssm-agent
aws --version
java -version
```

### Step 2: Create Production Environment using Cloudformation(webapp.yml)

### Step 3: Create IAM Role for EC2

1. Go to **IAM Console** → **Roles** → **Create role**
2. Select **AWS service** → **EC2** → **Next**
3. Attach these policies:
   - `AmazonSSMManagedInstanceCore`
   - `AmazonS3ReadOnlyAccess`
4. Name: `EC2-SSM-S3-Role`
5. Click **Create role**

**Attach role to EC2:**
- EC2 Console → Select instance → **Actions** → **Security** → **Modify IAM role**
- Choose `EC2-SSM-S3-Role` → **Update IAM role**

### Step 4: Verify SSM Connection

1. Go to **AWS Systems Manager** → **Fleet Manager**
2. Wait 5 minutes for instance to appear
3. Instance should show status: **Online**

### Step 5: Create Lambda Function

1. **Lambda Console** → **Create function**
   - Function name: `DeployToEC2`
   - Runtime: `Python 3.12`
   - Click **Create function**

2. Copy the Lambda code (see Configuration Files section)
3. Update `INSTANCE_ID` with your EC2 instance ID
4. Click **Deploy**

5. Configure timeout:
   - **Configuration** → **General configuration** → **Edit**
   - Timeout: `5 minutes (300 seconds)`
   - Click **Save**

### Step 6: Add Permissions to Lambda

1. Lambda → **Configuration** → **Permissions**
2. Click the **Role name** (opens IAM console)
3. **Add permissions** → **Attach policies**
4. Attach:
   - `AmazonSSMFullAccess`
   - `AmazonS3ReadOnlyAccess`
5. Click **Attach policies**

### Step 7: Configure S3 Event Trigger

1. Go to your **S3 artifact bucket**
2. **Properties** → **Event notifications** → **Create event notification**

Configuration:
- **Event name**: `DeploymentTrigger`
- **Suffix**: `.zip`
- **Event types**: ✅ All object create events
- **Destination**: Lambda function
- **Lambda**: `DeployToEC2`
- Click **Save changes**

### Step 8: Configure Security Group

Allow HTTP and Tomcat traffic:

1. EC2 → **Security Groups** → Select your instance's security group
2. **Inbound rules** → **Edit inbound rules**
3. Add rules:
   - Type: `HTTP`, Port: `80`, Source: `0.0.0.0/0`
   - Type: `Custom TCP`, Port: `8080`, Source: `0.0.0.0/0`
4. **Save rules**

### Step 9: Test the Pipeline

1. **Push code to GitHub** or trigger CodeBuild manually
2. **Watch CodeBuild** - Should complete successfully
3. **Check S3** - New ZIP file should appear
4. **Check Lambda logs** - CloudWatch Logs should show execution
5. **Check SSM** - Systems Manager → Run Command
6. **Access application**:
   - Direct Tomcat: `http://YOUR_EC2_IP:8080/web-project/`
   - Through Apache: `http://YOUR_EC2_IP/`

---

## 🔄 Understanding the Pipeline

### Complete Deployment Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. Developer pushes code to GitHub                     │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 2. GitHub webhook triggers CodeBuild                   │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 3. CodeBuild runs buildspec.yml                        │
│    - Installs Java 8 (Corretto)                        │
│    - Runs: mvn clean package                           │
│    - Creates: web-project.war                          │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 4. CodeBuild packages artifacts                        │
│    - target/web-project.war                            │
│    - scripts/install_dependencies.sh                   │
│    - scripts/start_server.sh                           │
│    → Creates: my-app.zip                               │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 5. CodeBuild uploads my-app.zip to S3                  │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 6. S3 event notification triggers Lambda               │
│    Event payload contains:                             │
│    - Bucket name                                       │
│    - File key (my-app.zip)                            │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 7. Lambda extracts S3 details from event               │
│    Sends SSM command to EC2                            │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 8. EC2 (via SSM Agent) receives commands               │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 9. EC2 downloads: aws s3 cp s3://bucket/my-app.zip     │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 10. EC2 extracts: unzip my-app.zip                     │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 11. EC2 stops old services                             │
│     sudo systemctl stop httpd                          │
│     sudo systemctl stop tomcat                         │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 12. EC2 cleans old deployment                          │
│     rm -rf /var/lib/tomcat/webapps/web-project*        │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 13. EC2 deploys new WAR                                │
│     cp web-project.war → /var/lib/tomcat/webapps/      │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 14. EC2 runs install_dependencies.sh                   │
│     - Ensures Java, Tomcat, Apache installed           │
│     - Configures Apache reverse proxy                  │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 15. EC2 starts Tomcat                                  │
│     sudo systemctl start tomcat                        │
│     → Tomcat auto-extracts web-project.war            │
│     → Creates /var/lib/tomcat/webapps/web-project/    │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 16. Wait 30 seconds for deployment                     │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 17. EC2 starts Apache httpd                            │
│     sudo systemctl start httpd                         │
│     → Proxies port 80 to Tomcat port 8080             │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 18. Application is LIVE! ✅                            │
│     http://YOUR_IP:8080/web-project/ (Direct)          │
│     http://YOUR_IP/ (Via Apache)                       │
└─────────────────────────────────────────────────────────┘
```

### How Tomcat Deploys WAR Files

**Automatic Hot Deployment:**

```bash
# You copy WAR file
sudo cp web-project.war /var/lib/tomcat/webapps/

# Tomcat automatically:
# 1. Detects new WAR file (checks every 15 seconds)
# 2. Creates directory: web-project/
# 3. Extracts WAR contents into directory
# 4. Loads the web application
# 5. Makes it available at /web-project/

# Final directory structure:
/var/lib/tomcat/webapps/
├── web-project.war          # Original WAR file
└── web-project/             # Auto-extracted directory
    ├── WEB-INF/
    │   ├── web.xml
    │   ├── classes/
    │   └── lib/
    ├── META-INF/
    └── index.jsp
```


### AWS Systems Manager (SSM)

**Why I used SSM instead of SSH:**

| SSH | SSM |
|-----|-----|
| ❌ Need SSH keys | ✅ No keys needed |
| ❌ Open port 22 | ✅ No ports needed |
| ❌ Security risk | ✅ IAM-based security |
| ❌ Manual setup | ✅ Automated |
| ❌ No audit trail | ✅ Full logging |

---


## 🐛 Troubleshooting and (Issues I have faced and how I Troubleshoot Them)

### Pipeline Not Triggering

**Check CodeBuild:**
```bash
# Verify GitHub webhook
# CodeBuild → Build projects → Your project → Webhook
```

**Check S3 Event:**
```bash
# S3 → Your bucket → Properties → Event notifications
# Should see: DeploymentTrigger
```

### Lambda Not Executing

**Check Lambda logs:**
```bash
# AWS Console → Lambda → Monitor → CloudWatch Logs
```

**Check S3 permissions:**
```bash
# Lambda needs permission to receive S3 events
# S3 bucket policy should allow Lambda invocation
```

### SSM Commands Failing

**Check SSM Agent on EC2:**
```bash
ssh -i your-key.pem ec2-user@your-ec2-ip

# Check SSM Agent status
sudo systemctl status amazon-ssm-agent

# Restart if needed
sudo systemctl restart amazon-ssm-agent

# Check logs
sudo tail -f /var/log/amazon/ssm/amazon-ssm-agent.log
```

**Check IAM Role:**
```bash
# EC2 must have SSM permissions
# IAM → Roles → Your EC2 role
# Should have: AmazonSSMManagedInstanceCore
```

**Check Fleet Manager:**
```bash
# AWS Console → Systems Manager → Fleet Manager
# Your instance should appear as "Online"
```

### Application Returns 404

**Check WAR deployment:**
```bash
ssh -i your-key.pem ec2-user@your-ec2-ip

# 1. Check if WAR exists
ls -lh /var/lib/tomcat/webapps/

# 2. Check if extracted
ls -lh /var/lib/tomcat/webapps/web-project/

# 3. Check Tomcat logs
sudo tail -100 /var/log/tomcat/catalina.out

# 4. Look for deployment messages
sudo grep -i "deployment" /var/log/tomcat/catalina.out

# 5. Test Tomcat directly
curl http://localhost:8080/web-project/
```

**Check Tomcat service:**
```bash
# Check status
sudo systemctl status tomcat

# Restart if needed
sudo systemctl restart tomcat

# Watch logs in real-time
sudo tail -f /var/log/tomcat/catalina.out
```

### Apache Proxy Not Working

**Check Apache status:**
```bash
# Status
sudo systemctl status httpd

# Test configuration
sudo httpd -t

# Check error logs
sudo tail -f /var/log/httpd/error_log

# Check access logs
sudo tail -f /var/log/httpd/access_log
```

**Test proxy manually:**
```bash
# Should work (Tomcat direct)
curl http://localhost:8080/web-project/

# Should work (Apache proxy)
curl http://localhost/

# If Apache works locally but not remotely, check Security Group
```

### Build Fails in CodeBuild

**Common issues:**

```bash
# Issue: Maven dependency download fails
# Solution: Check internet connectivity

# Issue: Java version mismatch
# Solution: Verify runtime-versions in buildspec.yml

# Issue: Build timeout
# Solution: Increase timeout in CodeBuild project settings
```

**Check build logs:**
```bash
# AWS Console → CodeBuild → Build history → Select build
# View complete build log
```

