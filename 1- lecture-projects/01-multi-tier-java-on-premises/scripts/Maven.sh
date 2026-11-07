#!/bin/bash
set -e

# Install required packages
sudo dnf install -y java-11-openjdk java-11-openjdk-devel maven git sshpass

# Validate installations
java -version
mvn -version
git --version
sshpass -V

# Clone project
cd /tmp

if [ ! -d vprofile-project ]; then
	git clone -b main https://github.com/hkhcoder/vprofile-project.git
fi

cd vprofile-project

# Build WAR file
mvn clean package

# Validate WAR file
if [ ! -s target/vprofile-v2.war ]; then
	echo "ERROR: WAR file not found or empty!"
	exit 1
fi

echo "WAR build successful."

# Stop Tomcat and Delete Existing WAR on Tomcat server
# sudo sshpass -p 'vagrant' ssh -o StrictHostKeyChecking=accept-new vagrant@app01 'sudo systemctl stop tomcat'
# sudo sshpass -p 'vagrant' ssh -o StrictHostKeyChecking=accept-new vagrant@app01 'sudo  rm -rf /usr/local/tomcat/webapps/ROOT*'

# Copy WAR to Tomcat server
sshpass -p 'vagrant' scp target/vprofile-v2.war vagrant@app01:/tmp
#sshpass -p 'vagrant' scp target/vprofile-v2.war vagrant@app01:/usr/local/tomcat/webapps/ROOT.war
sshpass -p 'vagrant' ssh vagrant@app01 'sudo mv /tmp/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war'

# Start Tomcat server
# sudo sshpass -p 'vagrant' ssh -o StrictHostKeyChecking=accept-new vagrant@app01 'sudo systemctl start tomcat'
# sudo sshpass -p 'vagrant' ssh -o StrictHostKeyChecking=accept-new vagrant@app01 'sudo chown tomcat.tomcat /usr/local/tomcat/webapps -R'
sshpass -p 'vagrant' ssh -o StrictHostKeyChecking=accept-new vagrant@app01 'sudo systemctl restart tomcat'

echo "WAR copied successfully to Tomcat."
