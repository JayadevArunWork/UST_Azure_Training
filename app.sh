#!/bin/bash
cd /home/surya
apt-get update -y
apt-get install nginx -y
apt-get install nodejs -y
apt-get install npm -y
apt-get install git -y
git clone https://github.com/Suryaa11/Fitness_Tracker.git
cat <<EOF > /etc/nginx/sites-available/custom
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:5000;
    }
}   
EOF
ln -s /etc/nginx/sites-available/custom /etc/nginx/sites-enabled/
cd /etc/nginx/sites-enabled
rm -rf default
systemctl restart nginx
cd /home/surya/Fitness_Tracker/server
npm i
node app.js
