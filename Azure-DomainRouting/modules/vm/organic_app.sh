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
    <title>Organic Ghee Store</title>
    <style>
        body { font-family: Arial; background: #FFF8DC; text-align: center; padding: 50px; }
        h1 { color: #8B6914; font-size: 2.5em; }
        .card { background: white; padding: 20px; border-radius: 10px; margin: 15px auto; width: 45%; display: inline-block; box-shadow: 0 4px 10px rgba(0,0,0,0.1); }
        .price { color: #DAA520; font-size: 1.4em; font-weight: bold; }
        .btn { background: #DAA520; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
        .info { background: #333; color: #0f0; padding: 10px; border-radius: 5px; margin-top: 20px; font-family: monospace; }
    </style>
</head>
<body>
    <h1>Organic Ghee Store</h1>
    <p>Pure | Natural | Traditional</p>
    <div class="card"><h2>Pure Cow Ghee</h2><div class="price">Rs. 599 / 500ml</div><button class="btn">Add to Cart</button></div>
    <div class="card"><h2>Buffalo Ghee</h2><div class="price">Rs. 799 / 500ml</div><button class="btn">Add to Cart</button></div>
    <div class="card"><h2>Herbal Ghee</h2><div class="price">Rs. 999 / 500ml</div><button class="btn">Add to Cart</button></div>
    <div class="card"><h2>Premium Ghee</h2><div class="price">Rs. 1299 / 500ml</div><button class="btn">Add to Cart</button></div>
    <div class="info"><p>Server: HOSTNAME_PLACEHOLDER | IP: IP_PLACEHOLDER</p></div>
</body>
</html>
EOF

sed -i "s/HOSTNAME_PLACEHOLDER/$MYHOSTNAME/g" /var/www/html/index.html
sed -i "s/IP_PLACEHOLDER/$MYIP/g" /var/www/html/index.html
chown -R www-data:www-data /var/www/html
systemctl restart nginx
echo "=== App Installed ==="