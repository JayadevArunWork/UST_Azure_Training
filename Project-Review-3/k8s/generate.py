import os

services = [
    {"name": "frontend", "port": 80, "max_repl": 10},
    {"name": "auth", "port": 3001, "max_repl": 6},
    {"name": "appointment", "port": 3002, "max_repl": 8},
    {"name": "pharmacy", "port": 3003, "max_repl": 6},
    {"name": "notify", "port": 3004, "max_repl": 6},
    {"name": "ai", "port": 3005, "max_repl": 6}
]

base_dir = "c:/Users/Admin/Downloads/Carenest-Azure/k8s"

for svc in services:
    name = svc["name"]
    port = svc["port"]
    max_repl = svc["max_repl"]

    # DEPLOYMENT
    dep_yaml = f"""apiVersion: apps/v1
kind: Deployment
metadata:
  name: {name}-deployment
  namespace: carenest-dev
  labels:
    app: {name}-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: {name}-service
  template:
    metadata:
      labels:
        app: {name}-service
    spec:
      serviceAccountName: carenest-sa
      terminationGracePeriodSeconds: 30
      initContainers:
      - name: wait-for-cosmos
        image: busybox:1.35
        command: ['sh', '-c', 'until nslookup jd-carenest-new-cosmos.mongo.cosmos.azure.com; do echo waiting for cosmos; sleep 2; done;']
      containers:
      - name: {name}-service
        image: jdcarenestnewacr.azurecr.io/{name}:latest
        imagePullPolicy: Always
        ports:
        - containerPort: {port}
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: {port}
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: {port}
          initialDelaySeconds: 15
          periodSeconds: 5
        envFrom:
        - secretRef:
            name: carenest-secrets
        - configMapRef:
            name: app-config
        {'- configMapRef:' + chr(10) + '            name: ai-config' if name == 'ai' else ''}
        {'- configMapRef:' + chr(10) + '            name: entra-config' if name == 'auth' else ''}
        volumeMounts:
        - name: secrets-store-inline
          mountPath: "/mnt/secrets-store"
          readOnly: true
      volumes:
        - name: secrets-store-inline
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "jd-carenest-new-kv-secrets"
"""
    with open(os.path.join(base_dir, f"deployments/{name}-deployment.yaml"), "w") as f:
        f.write(dep_yaml)

    # SERVICE
    svc_yaml = f"""apiVersion: v1
kind: Service
metadata:
  name: {name}-service
  namespace: carenest-dev
spec:
  selector:
    app: {name}-service
  ports:
  - port: {port}
    targetPort: {port}
"""
    with open(os.path.join(base_dir, f"services/{name}-service.yaml"), "w") as f:
        f.write(svc_yaml)

    # HPA
    hpa_yaml = f"""apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {name}-hpa
  namespace: carenest-dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {name}-deployment
  minReplicas: 2
  maxReplicas: {max_repl}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
"""
    with open(os.path.join(base_dir, f"hpa/{name}-hpa.yaml"), "w") as f:
        f.write(hpa_yaml)

    # PDB
    pdb_yaml = f"""apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {name}-pdb
  namespace: carenest-dev
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: {name}-service
"""
    with open(os.path.join(base_dir, f"pdb/{name}-pdb.yaml"), "w") as f:
        f.write(pdb_yaml)

print("Generated all Kubernetes manifests for services.")
