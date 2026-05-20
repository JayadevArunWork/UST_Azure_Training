#!/bin/bash
cd /home/surya
apt-get update -y
apt-get install nginx -y
apt-get install nodejs -y  
apt-get install npm -y
apt-get install git -y
git clone https://github.com/Msocial123/organic-ghee
cat <<EOF > /etc/nginx/sites-available/custom
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:5656;
    }
}  
EOF
ln -s /etc/nginx/sites-available/custom /etc/nginx/sites-enabled/
cd /etc/nginx/sites-enabled
rm -rf default
systemctl restart nginx
cd /home/surya/organic-ghee
npm i
node src/app.js
