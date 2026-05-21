#!/bin/bash
exec > /var/log/ghee-install.log 2>&1
echo "=== Starting Installation ==="
date

apt-get update -y
apt-get install -y apache2 stress

systemctl start apache2
systemctl enable apache2
sleep 5

MYHOSTNAME=$(hostname)
MYIP=$(hostname -I | awk '{print $1}')

cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Organic Ghee Store</title>
    <style>
        body { font-family: Arial; background: linear-gradient(135deg, #FFF8DC, #FFD700); padding: 20px; text-align: center; }
        header { background: #8B6914; color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }
        .products { display: flex; flex-wrap: wrap; gap: 20px; justify-content: center; }
        .card { background: white; border-radius: 15px; padding: 25px; width: 280px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
        .card h2 { color: #8B6914; }
        .price { font-size: 1.5em; color: #DAA520; font-weight: bold; margin: 10px 0; }
        .btn { background: #DAA520; color: white; border: none; padding: 10px 25px; border-radius: 25px; cursor: pointer; }
        .info { background: #333; color: #0f0; padding: 15px; border-radius: 10px; margin-top: 30px; font-family: monospace; }
    </style>
</head>
<body>
    <header><h1>Organic Ghee Store</h1><p>Pure | Natural | Traditional</p></header>
    <div class="products">
        <div class="card"><h2>Pure Cow Ghee</h2><p>A2 milk desi cow ghee</p><div class="price">Rs. 599 / 500ml</div><button class="btn">Add to Cart</button></div>
        <div class="card"><h2>Buffalo Ghee</h2><p>Rich and creamy</p><div class="price">Rs. 799 / 500ml</div><button class="btn">Add to Cart</button></div>
        <div class="card"><h2>Herbal Ghee</h2><p>Infused with herbs</p><div class="price">Rs. 999 / 500ml</div><button class="btn">Add to Cart</button></div>
        <div class="card"><h2>Premium Ghee</h2><p>Handcrafted small batch</p><div class="price">Rs. 1299 / 500ml</div><button class="btn">Add to Cart</button></div>
    </div>
    <div class="info"><p>Server: HOSTNAME_PLACEHOLDER | IP: IP_PLACEHOLDER</p><p>Powered by Azure VM Scale Sets</p></div>
</body>
</html>
HTMLEOF

sed -i "s/HOSTNAME_PLACEHOLDER/$MYHOSTNAME/g" /var/www/html/index.html
sed -i "s/IP_PLACEHOLDER/$MYIP/g" /var/www/html/index.html

chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
systemctl restart apache2

echo "=== Installation Complete ==="
date