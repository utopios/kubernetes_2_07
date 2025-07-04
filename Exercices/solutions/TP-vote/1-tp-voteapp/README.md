## 🎯 **Objectif du TP : Déployer l’application “vote” avec Kubernetes**

### 🧩 **Contexte**
L'application "vote" est une architecture composée de plusieurs microservices communiquant entre eux. Elle permet aux utilisateurs de voter pour une option (par exemple : "Cats" ou "Dogs") et d'afficher les résultats en temps réel. Cette application est souvent utilisée comme exemple pour illustrer un déploiement multi-conteneurs.

---

### 🔧 **Composants de l'application**

| Composant  | Rôle                                                                 |
|------------|----------------------------------------------------------------------|
| `vote`     | Frontend web (écrit en Python/Flask), pour voter                     |
| `result`   | Frontend web (écrit en Node.js), pour voir les résultats             |
| `worker`   | Service backend (écrit en .NET), lit les votes depuis Redis et les stocke dans Postgres |
| `redis`    | File d’attente (in-memory queue) pour stocker les votes temporairement |
| `postgres` | Base de données relationnelle pour stocker les résultats des votes   |

---

### 📦 **Travail demandé**

1. **Créer un cluster Kubernetes (local ou distant)**  
   - Option : Minikube, Kind, K3s, MicroK8s ou un cluster cloud (GKE, AKS, EKS)

2. **Définir les manifests YAML nécessaires**
   - 1 Deployment par service : `vote`, `result`, `worker`, `redis`, `postgres`
   - 1 Service par composant, dont certains en `ClusterIP`, d'autres en `NodePort` ou `LoadBalancer`

3. **Configurer les services**
   - `vote` et `result` doivent être accessibles depuis le navigateur
   - `worker` n’est pas exposé, il communique en interne avec Redis et Postgres
   - `redis` et `postgres` sont uniquement accessibles depuis les autres pods

4. **Déployer tous les composants dans un namespace dédié**  
   Exemple : `vote-app`


5. **Tester l’application**
   - Accéder à l’interface de vote
   - Voter plusieurs fois
   - Vérifier que les résultats s’affichent en temps réel


**6. Étendre l’application : types Kubernetes adaptés, collecte de logs, sauvegarde automatisée**

Dans cette nouvelle partie, vous allez transformer l’application pour qu’elle réponde à des exigences **réalistes de production**, en adaptant les types de déploiement, en ajoutant une **collecte de logs centralisée**, et en automatisant la **sauvegarde de la base de données**.

#### A. Adapter les objets Kubernetes

1. **Analysez les besoins de chaque composant** et remplacez les `Deployment` par le type le plus approprié

#### B. Créer et déployer un système de collecte de logs

Vous allez créer une **nouvelle application Python**, nommée `log-reader`, et une **nouvelle base de données** appelée `log-db`.

1. **Créer `log-db` :**

   * Il s’agit d’une nouvelle instance de **PostgreSQL** dédiée au stockage des logs.
   * Déployez-la avec le bon type.
   * Exposez-la uniquement en interne.

2. **Développer `log-reader` :**

   * Cette application Python doit :

     * Lire les logs stdout des pods (vous pouvez simuler cela via `/var/log/containers` ou en montant un volume de logs).
     * Insérer ces logs dans la base `log-db`.

3. **Déployer `log-reader`** :

   * pour qu’un pod soit lancé sur chaque nœud du cluster.
   * Cette application doit pouvoir se connecter à `log-db` via un service interne.

#### C. Automatiser la sauvegarde avec une CronJob

1. **Créer une application Python `db-dumper`** qui :

   * Effectue un dump de la base `postgres` (ex : avec `pg_dump`)
   * Archive le fichier (ex : `.tar.gz`)
   * L’envoie par mail (via `smtplib`, ou un utilitaire système comme `mail`)

2. **Déployer l’application dans Kubernetes** :

   * Fréquence : **deux fois par jour** (ex : `0 6,18 * * *`)
   * Le conteneur doit inclure les outils nécessaires (client PostgreSQL, Python avec les bons modules)
   * Le mail peut être simulé avec un log

