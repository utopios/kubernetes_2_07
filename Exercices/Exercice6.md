# Exercice 6 – Jobs et CronJobs pour Ghost (Maintenance et Sauvegardes)


Les applications en production nécessitent des tâches de maintenance régulières :
- **Sauvegardes quotidiennes** de la base de données MySQL
- **Nettoyage hebdomadaire** des logs et fichiers temporaires
- **Optimisation mensuelle** des bases de données

Actuellement, ces tâches sont déployées comme des **Deployments continus** qui consomment des ressources inutilement. Vous devez les **convertir en Jobs/CronJobs** pour qu'elles s'exécutent uniquement quand nécessaire.

---

## Deployments fournis à convertir

### 1. Deployment - Sauvegarde continue (à convertir en Job ponctuel)

**Deployment fourni :**

```yaml
# ghost-backup-deployment.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ghost-backup-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ghost-backup-continuous
  labels:
    app: ghost-backup
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ghost-backup
  template:
    metadata:
      labels:
        app: ghost-backup
    spec:
      containers:
      - name: mysql-backup
        image: mysql:8.0
        env:
        - name: MYSQL_HOST
          value: "mysql-service"
        - name: MYSQL_USER
          value: "ghost"
        - name: MYSQL_PASSWORD
          value: "ghostpassword"
        - name: MYSQL_DATABASE
          value: "ghost"
        command:
        - /bin/bash
        - -c
        - |
          while true; do
            echo "=== Sauvegarde en cours ==="
            BACKUP_FILE="/backup/ghost-backup-$(date +%Y-%m-%d-%H-%M).sql"
            echo "Sauvegarde vers: $BACKUP_FILE"
            
            mysqldump -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE > $BACKUP_FILE
            
            if [ $? -eq 0 ]; then
              echo "✅ Sauvegarde réussie: $BACKUP_FILE"
              echo "Taille: $(du -h $BACKUP_FILE | cut -f1)"
            else
              echo "❌ Échec de la sauvegarde"
            fi
            
            echo "Attente de 24 heures..."
            sleep 86400  # 24 heures
          done
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        volumeMounts:
        - name: backup-storage
          mountPath: /backup
      volumes:
      - name: backup-storage
        persistentVolumeClaim:
          claimName: ghost-backup-pvc
      restartPolicy: Always
```

**Votre mission :**
- **Convertir ce Deployment en Job ponctuel** nommé `ghost-backup-manual`
- **Créer un CronJob** nommé `ghost-backup-daily` pour exécution quotidienne à 2h00
- **Supprimer la boucle infinie** et adapter pour exécution unique
- **Changer restartPolicy** en `Never` pour le Job et `OnFailure` pour le CronJob
- **Ajouter la gestion des anciennes sauvegardes** (conserver 7 jours)

### 2. Deployment - Nettoyage continu (à convertir en CronJob hebdomadaire)

**Deployment fourni :**

```yaml
# ghost-cleanup-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ghost-cleanup-continuous
  labels:
    app: ghost-cleanup
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ghost-cleanup
  template:
    metadata:
      labels:
        app: ghost-cleanup
    spec:
      containers:
      - name: ghost-cleanup
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "=== Nettoyage des logs Ghost ==="
            
            cd /var/lib/ghost/content
            
            echo "Fichiers avant nettoyage:"
            find . -name "*.log" -type f -exec ls -la {} \; 2>/dev/null || echo "Aucun log trouvé"
            
            # Supprimer les logs de plus de 7 jours
            echo "Suppression des logs anciens..."
            find . -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
            
            # Supprimer les fichiers temporaires
            echo "Suppression des fichiers temporaires..."
            find . -name "*.tmp" -type f -delete 2>/dev/null || true
            
            echo "Fichiers après nettoyage:"
            find . -name "*.log" -type f -exec ls -la {} \; 2>/dev/null || echo "Aucun log restant"
            
            echo "Nettoyage terminé. Attente d'une semaine..."
            sleep 604800  # 7 jours
          done
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: ghost-content
          mountPath: /var/lib/ghost/content
      volumes:
      - name: ghost-content
        persistentVolumeClaim:
          claimName: ghost-content-pvc
      restartPolicy: Always
```

**Votre mission :**
- **Convertir en CronJob** nommé `ghost-cleanup-logs`
- **Planning** : Tous les dimanches à 3h00 (`0 3 * * 0`)
- **Supprimer la boucle infinie** et le `sleep`
- **Adapter pour exécution unique** hebdomadaire
- **Ajouter des vérifications** d'espace disque

### 3. Deployment - Optimisation continue MySQL (à convertir en CronJob mensuel)

**Deployment fourni :**

```yaml
# mysql-optimize-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-optimize-continuous
  labels:
    app: mysql-optimize
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-optimize
  template:
    metadata:
      labels:
        app: mysql-optimize
    spec:
      containers:
      - name: mysql-optimize
        image: mysql:8.0
        env:
        - name: MYSQL_HOST
          value: "mysql-service"
        - name: MYSQL_USER
          value: "root"
        - name: MYSQL_PASSWORD
          value: "ghostpassword"
        - name: MYSQL_DATABASE
          value: "ghost"
        command:
        - /bin/bash
        - -c
        - |
          while true; do
            echo "=== Optimisation MySQL ==="
            
            mysql -h $MYSQL_HOST -u $MYSQL_USER -p$MYSQL_PASSWORD -D $MYSQL_DATABASE << 'EOF'
            SELECT 'Début optimisation' as info;
            SHOW TABLES;
            
            ANALYZE TABLE posts, users, tags;
            OPTIMIZE TABLE posts, users, tags;
            
            SELECT 'Optimisation terminée' as info;
            SELECT 
              table_name,
              ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
            FROM information_schema.TABLES 
            WHERE table_schema = 'ghost';
            EOF
            
            if [ $? -eq 0 ]; then
              echo "✅ Optimisation MySQL réussie"
            else
              echo "❌ Échec optimisation MySQL"
            fi
            
            echo "Attente d'un mois..."
            sleep 2592000  # 30 jours
          done
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      restartPolicy: Always
```

**Votre mission :**
- **Convertir en CronJob** nommé `mysql-optimize`
- **Planning** : Le 1er de chaque mois à 1h00 (`0 1 1 * *`)
- **Supprimer la boucle infinie** et le `sleep`
- **Ajouter une gestion d'erreur** appropriée
- **Limiter la concurrence** (`concurrencyPolicy: Forbid`)

---

## Instructions de conversion

### Étapes de conversion obligatoires

1. **Analyser les Deployments fournis**
   - Identifier la logique métier dans les scripts
   - Repérer les boucles infinies à supprimer
   - Noter les volumes et variables d'environnement

2. **Créer les Jobs/CronJobs correspondants**
   - **Job ponctuel** : `ghost-backup-manual`
   - **CronJob quotidien** : `ghost-backup-daily` (`0 2 * * *`)
   - **CronJob hebdomadaire** : `ghost-cleanup-logs` (`0 3 * * 0`)
   - **CronJob mensuel** : `mysql-optimize` (`0 1 1 * *`)
