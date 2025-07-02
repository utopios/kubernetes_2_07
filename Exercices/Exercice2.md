# Exercice : Ghost avec Sondes et Lifecycle Hooks

**Sondes à configurer :**

**Startup Probe :**
- Type : HTTP GET sur `/ghost/api/v4/admin/site/`
- Port : `2368`
- Headers : `Accept: application/json`
- Délai initial : `60 secondes` (Ghost met du temps à démarrer)
- Période : `10 secondes`
- Échecs autorisés : `6`
- Timeout : `5 secondes`

**Readiness Probe :**
- Type : HTTP GET sur `/`
- Port : `2368`
- Headers : `User-Agent: k8s-readiness`
- Délai initial : `30 secondes`
- Période : `5 secondes`
- Échecs autorisés : `3`
- Timeout : `3 secondes`

**Liveness Probe :**
- Type : HTTP GET sur `/ghost/api/v4/admin/users/me/`
- Port : `2368`
- Délai initial : `120 secondes`
- Période : `30 secondes`
- Échecs autorisés : `2`
- Timeout : `10 secondes`

## 2. Ajout des Lifecycle Hooks

Configurez les hooks suivants :

**PostStart Hook :**
- Type : `exec`
- Commandes :
  - Créer un répertoire `/var/log/ghost`
  - Écrire un message de démarrage avec timestamp dans `/var/log/ghost/startup.log`
  - Attendre que Ghost soit complètement initialisé (5 secondes)

**PreStop Hook :**
- Type : `exec`
- Commandes :
  - Écrire un message d'arrêt dans `/var/log/ghost/shutdown.log`
  - Attendre 10 secondes pour permettre aux connexions de se terminer proprement
  - Effectuer un arrêt gracieux

## 3. Configuration des ressources et sécurité

Ajoutez :
- **Ressources** :
  - Requests : `256Mi` mémoire, `200m` CPU
  - Limits : `512Mi` mémoire, `500m` CPU
- **Grace period** : `30 secondes`
- **Security context** : utilisateur non-root
