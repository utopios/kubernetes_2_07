# Exercice Déploiements Ghost et MySQL 

## Créer le cluster k3d

```bash
# Créer le cluster avec port NodePort exposé
k3d cluster create ghost-blog \
  --agents 2 \
  --port "30080:30080@loadbalancer"

```

## 1. Déploiement MySQL (Base de données)

```yaml
# mysql-deployment.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "ghostpassword"
        - name: MYSQL_DATABASE
          value: "ghost"
        - name: MYSQL_USER
          value: "ghost"
        - name: MYSQL_PASSWORD
          value: "ghostpassword"
        ports:
        - containerPort: 3306
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
```

```bash
kubectl apply -f mysql-deployment.yaml
```

## 2. Déploiement Ghost (Application)

```yaml
# ghost-deployment.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ghost-content-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: local-path
  resources:
    requests:
      storage: 500Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ghost
  labels:
    app: ghost
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ghost
  template:
    metadata:
      labels:
        app: ghost
    spec:
      containers:
      - name: ghost
        image: ghost:5-alpine
        env:
        - name: database__client
          value: "mysql"
        - name: database__connection__host
          value: "mysql-service"
        - name: database__connection__user
          value: "ghost"
        - name: database__connection__password
          value: "ghostpassword"
        - name: database__connection__database
          value: "ghost"
        - name: url
          value: "http://localhost:30080"
        - name: NODE_ENV
          value: "production"
        ports:
        - containerPort: 2368
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 2368
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 2368
          initialDelaySeconds: 30
          periodSeconds: 5
        volumeMounts:
        - name: ghost-content
          mountPath: /var/lib/ghost/content
      volumes:
      - name: ghost-content
        persistentVolumeClaim:
          claimName: ghost-content-pvc
```

```bash
kubectl apply -f ghost-deployment.yaml
```


## Exercice : Créer les Services

**Maintenant que les déploiements sont prêts, votre mission est de créer :**

### À créer par les stagiaires :

1. **Service ClusterIP pour MySQL**
   - Nom : `mysql-service`
   - Port : 3306
   - Sélecteur : `app: mysql`

2. **Service ClusterIP pour Ghost**
   - Nom : `ghost-clusterip-service`
   - Port : 80 → 2368
   - Sélecteur : `app: ghost`

3. **Service NodePort pour Ghost**
   - Nom : `ghost-nodeport-service`
   - Port : 80 → 2368
   - NodePort : 30080
   - Sélecteur : `app: ghost`

