## Exercice : Deployment Ghost avec Historisation et Réplication Avancée

### 1. Création du Deployment avec historisation

Créez un fichier **ghost_deployment.yaml** définissant un Deployment ayant les propriétés suivantes :
* nom: *ghost*
* nombre de replicas: 3
* définition d'un selector sur le label *app: ghost*
* configuration pour conserver 10 révisions dans l'historique
* stratégie de mise à jour RollingUpdate avec maxUnavailable: 1 et maxSurge: 1
* spécification du Pod:
   * label *app: ghost* et *version: "4.0"*
   * un container nommé *ghost* basé sur l'image *ghost:4* et exposant le port *2368*
   * limites de ressources : 256Mi de mémoire et 200m de CPU
* annotation pour tracer le changement : "Déploiement initial Ghost v4.0"

Créez ensuite la ressource spécifiée.

### 2. Vérification du statut initial

À l'aide de *kubectl*, examinez le statut du Deployment *ghost* et vérifiez l'historique des révisions.
À partir de ces informations, que pouvez-vous dire par rapport au nombre de Pods gérés par ce Deployment ?

### 3. Analyse des Pods et ReplicaSets

À l'aide de *kubectl*, listez :
- Les Pods associés à ce Deployment
- Les ReplicaSets créés
- Les détails des Pods

### 4. Test de réplication et auto-guérison

Supprimez un Pod du Deployment et observez le comportement de Kubernetes.
Que se passe-t-il ? Combien de temps faut-il pour que le système se rétablisse ?

### 5. Mise à jour avec traçabilité

Effectuez une mise à jour de l'image vers *ghost:5* en utilisant la commande appropriée.
Ajoutez une annotation pour tracer ce changement : "Mise à jour vers Ghost v5.0".
Suivez le processus de mise à jour et vérifiez l'historique.

### 6. Scaling dynamique

Augmentez le nombre de replicas à 5 et tracez ce changement avec l'annotation "Scale up à 5 replicas".
Observez le processus de scaling et l'état des Pods.

### 7. Gestion d'incident et rollback

Simulez un problème en mettant à jour vers une version potentiellement problématique (*ghost:alpine*).
Tracez ce changement, observez les éventuels problèmes, puis effectuez un rollback vers la version précédente.
Documentez le rollback avec une annotation appropriée.

### 8. Tests de résilience

Testez la résilience du système en supprimant plusieurs Pods simultanément.

### 9. Analyse complète de l'historique

Examinez l'historique complet des révisions et analysez une révision spécifique de votre choix.
Comparez les différents ReplicaSets créés.

### 10. Questions d'analyse

**Réplication :**
1. Comment Kubernetes maintient-il le nombre de replicas demandé ?
2. Que se passe-t-il si un nœud tombe en panne ?

**Historisation :**
1. Combien de révisions sont conservées et pourquoi ?
2. Comment identifier quelle révision correspond à quelle modification ?
3. Dans quels cas utiliseriez-vous un rollback ?

### 11. Nettoyage

Supprimez toutes les ressources créées lors de cet exercice.