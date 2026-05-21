#!/bin/bash
exec > /var/log/app-install.log 2>&1
apt-get update -y
apt-get install -y nginx
systemctl start nginx
systemctl enable nginx

MYHOSTNAME=$(hostname)
MYIP=$(hostname -I | awk '{print $1}')

cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>FitLife App</title>
    <style>
        body { font-family: Arial; background: #E8F5E9; text-align: center; padding: 50px; }
        h1 { color: #2E7D32; font-size: 2.5em; }
        .card { background: white; padding: 20px; border-radius: 10px; margin: 15px auto; width: 45%; display: inline-block; box-shadow: 0 4px 10px rgba(0,0,0,0.1); }
        .price { color: #43A047; font-size: 1.4em; font-weight: bold; }
        .btn { background: #43A047; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
        .info { background: #333; color: #0f0; padding: 10px; border-radius: 5px; margin-top: 20px; font-family: monospace; }
    </style>
</head>
<body>
    <h1>FitLife App</h1>
    <p>Train | Eat | Sleep | Repeat</p>
    <div class="card"><h2>Basic Plan</h2><div class="price">Rs. 499 / month</div><button class="btn">Join Now</button></div>
    <div class="card"><h2>Premium Plan</h2><div class="price">Rs. 999 / month</div><button class="btn">Join Now</button></div>
    <div class="card"><h2>Personal Training</h2><div class="price">Rs. 2999 / month</div><button class="btn">Book Now</button></div>
    <div class="card"><h2>Annual Plan</h2><div class="price">Rs. 7999 / year</div><button class="btn">Get Started</button></div>
    <div class="info"><p>Server: HOSTNAME_PLACEHOLDER | IP: IP_PLACEHOLDER</p></div>
</body>
</html>
EOF

sed -i "s/HOSTNAME_PLACEHOLDER/$MYHOSTNAME/g" /var/www/html/index.html
sed -i "s/IP_PLACEHOLDER/$MYIP/g" /var/www/html/index.html
chown -R www-data:www-data /var/www/html
systemctl restart nginx
echo "=== App Installed ==="