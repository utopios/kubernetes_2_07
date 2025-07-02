# Exercice : Ghost avec Init Containers, Sidecar et Hooks

## Sujet de l'exercice

Vous allez étendre le déploiement Ghost précédent en ajoutant des containers spécialisés et des hooks de cycle de vie.

### 1. Configuration avancée avec Init Container

Modifiez le fichier **ghost_deployment.yaml** pour ajouter :

**Init Container :**
- Nom : *ghost-init*
- Image : *busybox:1.35*
- Mission : Vérifier que la base de données MySQL est accessible avant de démarrer Ghost
- Commande : Utiliser `nslookup` pour vérifier la résolution DNS de `mysql-service.default.svc.cluster.local`
- Attendre que la commande retourne un code de sortie 0
- Variables d'environnement :
  - `DB_HOST` : mysql-service.default.svc.cluster.local
  - `DB_PORT` : 3306

### 2. Ajout d'un Sidecar Container

Ajoutez un container sidecar avec les caractéristiques suivantes :

**Sidecar Container :**
- Nom : *log-forwarder*
- Image : *busybox:1.35*
- Rôle : Surveiller les logs de Ghost et les envoyer vers un service externe
- Volume partagé : `/var/log/ghost` (à monter dans les deux containers)
- Commande : `tail -f /var/log/ghost/access.log`
- Resources :
  - Requests : 50m CPU, 64Mi mémoire
  - Limits : 100m CPU, 128Mi mémoire

### 3. Configuration du Main Container avec Hooks

Modifiez le container principal Ghost pour inclure :

**PreStart Hook :**
- Type : Exec
- Commande : Créer un fichier de log d'initialisation dans `/var/log/ghost/startup.log`
- Message : "Ghost container starting at $(date)"

**PreStop Hook :**
- Type : Exec  
- Commande : Écrire un message de fermeture gracieuse
- Message : "Ghost container stopping at $(date)"
- Délai de grâce : 30 secondes

**Volume Mount :**
- Monter un volume `ghost-logs` sur `/var/log/ghost`

### 4. Ajout de Probes avancées

Configurez des sondes plus sophistiquées :

**Startup Probe :**
- HTTP GET sur `/ghost/api/v4/admin/site/`
- Port : 2368
- Délai initial : 60 secondes
- Période : 10 secondes
- Échecs autorisés : 6

**Readiness Probe améliorée :**
- HTTP GET avec header personnalisé
- Délai initial : 30 secondes
- Timeout : 5 secondes

**Liveness Probe améliorée :**
- Vérification de la santé de l'application
- Période : 60 secondes

### 5. Gestion des ressources et priorités

Configurez :
- **Classe de priorité** : Créer une PriorityClass `ghost-priority` avec valeur 1000
- **Ressources étendues** pour chaque container
- **Limites de sécurité** : SecurityContext avec utilisateur non-root

### 6. Configuration des variables d'environnement

Ajoutez les variables suivantes au main container :
- `NODE_ENV` : production
- `database__client` : mysql
- `database__connection__host` : mysql-service.default.svc.cluster.local
- `database__connection__user` : ghost
- `database__connection__password` : (à récupérer depuis un Secret)
- `database__connection__database` : ghostdb

### 7. Tests et validation

Après déploiement, effectuez les tests suivants :

**Test 1 - Init Container :**
- Vérifiez que l'init container s'exécute avant le main container
- Examinez les logs de l'init container
- Que se passe-t-il si la base de données n'est pas disponible ?

**Test 2 - Main Container et Hooks :**
- Vérifiez que les hooks preStart et preStop sont exécutés
- Examinez les fichiers de log créés par les hooks
- Testez un arrêt gracieux du Pod

**Test 3 - Sidecar Container :**
- Vérifiez que le sidecar fonctionne en parallèle
- Examinez les logs du sidecar
- Testez le volume partagé entre containers

**Test 4 - Probes :**
- Observez le comportement de la startup probe
- Testez les conditions d'échec des probes
- Simulez une panne pour tester la liveness probe

### 8. Exercices de troubleshooting

**Scénario 1 :** L'init container échoue
- Comment identifier la cause ?
- Quelles commandes utiliser pour diagnostiquer ?
- Comment corriger le problème ?

**Scénario 2 :** Le sidecar consomme trop de ressources
- Comment limiter l'impact sur le main container ?
- Comment ajuster les ressources dynamiquement ?

**Scénario 3 :** Les hooks ne s'exécutent pas
- Comment vérifier leur configuration ?
- Comment déboguer leur exécution ?

### 9. Monitoring et observabilité

Créez des scripts pour :
- Surveiller l'état de tous les containers dans le Pod
- Collecter les métriques de ressources de chaque container
- Analyser les logs de chaque container séparément
- Vérifier l'exécution des hooks

### 10. Optimisation et bonnes pratiques

**Questions d'analyse :**
1. Dans quels cas utiliseriez-vous chaque type de container ?
2. Comment optimiser l'ordre d'exécution des init containers ?
3. Quels sont les risques d'un sidecar mal configuré ?
4. Comment gérer les dépendances entre containers ?
5. Quelle stratégie adopter pour les ressources partagées ?

### 11. Extension avec plusieurs Init Containers

Ajoutez un second init container :
- Nom : *database-migrate*
- Image : *ghost:4*
- Mission : Exécuter les migrations de base de données
- Dépend de : l'init container précédent
- Commande : `knex-migrator init`



### 13. Nettoyage et documentation

- Documentez la configuration de chaque container
- Créez un diagramme de l'architecture multi-container
- Nettoyez toutes les ressources créées
- Rédigez un guide de dépannage pour les futurs utilisateurs
