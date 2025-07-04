**Objectif du TP : Déployer l'application "vote" avec Kubernetes**

**Contexte**
L'application "vote" est une architecture composée de plusieurs microservices communiquant entre eux. Elle permet aux utilisateurs de voter pour une option (par exemple : "Cats" ou "Dogs") et d'afficher les résultats en temps réel. Cette application est souvent utilisée comme exemple pour illustrer un déploiement multi-conteneurs sécurisé et cloisonné.

🔧 **Composants de l'application**

| Composant | Rôle | Image Docker |
|-----------|------|--------------|
| `vote` | Frontend web (écrit en Python/Flask), pour voter | `mohamed1780/vote` |
| `vote-ui` | Interface utilisateur pour le vote | `mohamed1780/vote-ui` |
| `result` | Frontend web (écrit en Node.js), pour voir les résultats | `mohamed1780/result` |
| `result-ui` | Interface utilisateur pour les résultats | `mohamed1780/result-ui` |
| `worker` | Service backend (écrit en .NET), lit les votes depuis Redis et les stocke dans Postgres | `mohamed1780/worker` |
| `redis` | File d'attente (in-memory queue) pour stocker les votes temporairement | `redis:alpine` |
| `postgres` | Base de données relationnelle pour stocker les résultats des votes | `postgres:15-alpine` |


1. **Créer un cluster Kubernetes (local ou distant)**
   * Option : k3d

2. **Définir les manifests YAML nécessaires**
   * 1 Deployment par service : `vote`, `vote-ui`, `result`, `result-ui`, `worker`, `redis`, `postgres`
   * 1 Service par composant, dont certains en `ClusterIP`, d'autres en `NodePort` ou `LoadBalancer`

3. **Configurer les services**
   * `vote`, `vote-ui`, `result` et `result-ui` doivent être accessibles depuis le navigateur
   * `worker` n'est pas exposé, il communique en interne avec Redis et Postgres
   * `redis` et `postgres` sont uniquement accessibles depuis les autres pods

4. **Gérer les volumes persistants**
   * Configurer un PersistentVolume et PersistentVolumeClaim pour PostgreSQL
   * Assurer la persistance des données de vote même en cas de redémarrage des pods

5. **Implémenter la sécurité réseau**
   * Créer des NetworkPolicy pour cloisonner les communications entre services
   * Autoriser uniquement les flux nécessaires (ex: worker → redis, worker → postgres, vote-ui → vote, result-ui → result)
   * Bloquer les communications non autorisées entre les composants

6. **Assurer le cloisonnement et la sécurité**
   * Déployer tous les composants dans un namespace dédié (ex: `vote-app`)
   * Configurer des SecurityContext appropriés pour les pods
   * Définir des ResourceQuotas et LimitRanges pour contrôler l'utilisation des ressources
   * Implémenter des ServiceAccounts dédiés avec des permissions minimales

7. **Configuration avancée**
   * Utiliser des ConfigMaps pour les configurations d'application
   * Gérer les secrets (mots de passe PostgreSQL) avec des objets Secret

8. **Tester l'application**
   * Accéder aux interfaces de vote et de résultats
   * Voter plusieurs fois
   * Vérifier que les résultats s'affichent en temps réel
   * Valider que les NetworkPolicy bloquent bien les communications non autorisées
   * Tester la persistance des données après redémarrage des pods
