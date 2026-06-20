import subprocess
val = "mongodb://jd-carenest-cosmos:Zh90HYmbh4GjyogadpzR4wqbb2fZrttBIaXg4L2ZCfQZr0xAepCOZfzPY7COheysvQX9ADNH6j83ACDb8ciXNQ==@jd-carenest-cosmos.mongo.cosmos.azure.com:10255/?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@jd-carenest-cosmos@"
subprocess.run(["az.cmd", "keyvault", "secret", "set", "--vault-name", "jd-carenest-kv", "--name", "cosmos-connection-string", "--value", val])
