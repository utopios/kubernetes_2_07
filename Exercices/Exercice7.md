# Exercice 7 – Migration vers Namespace dédié avec Pod Security Standards

L'équipe sécurité demande de **migrer l'application Ghost** depuis le namespace `default` vers un **namespace dédié sécurisé** avec des **Pod Security Standards (PSS)** appropriés pour renforcer la sécurité.

---

## Contexte de sécurité

L'architecture actuelle présente des risques :
- **Déploiement dans `default`** : Mauvaise pratique de sécurité
- **Pas de Pod Security Standards** : Pods peuvent s'exécuter avec des privilèges élevés
- **Mélange avec d'autres applications** : Pas d'isolation
- **Gestion des secrets** : Credentials visibles dans le namespace par défaut

L'objectif est de créer un **namespace dédié `ghost-app`** avec des Pod Security Standards appropriés.

---

## Architecture cible

```
┌─────────────────────────────────────────────────────────────┐
│                    CLUSTER KUBERNETES                      │
├─────────────────────────────────────────────────────────────┤
│  📦 default (vide - nettoyé)                               │
│     └─ Plus d'applications Ghost                           │
├─────────────────────────────────────────────────────────────┤
│  📦 ghost-app (PSS: baseline)                              │
│     ├─ Ghost application                                   │
│     ├─ MySQL StatefulSet                                   │
│     ├─ Jobs et CronJobs de maintenance                     │
│     ├─ Services (ClusterIP, NodePort)                      │
│     ├─ NetworkPolicies                                     │
│     ├─ PVC pour données et sauvegardes                     │
│     └─ Secrets dédiés                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Prérequis

Vous devez avoir l'environnement Ghost complet fonctionnel dans `default` :
- Ghost et MySQL déployés
- Services et NetworkPolicies configurés

---

## Instructions

### 1. Création du namespace avec Pod Security Standards

**Créer le namespace `ghost-app` avec PSS baseline :**
- Pod Security Standard : **baseline**
- Justification : Équilibre entre sécurité et fonctionnalité
- Permet à MySQL et Ghost de fonctionner avec des restrictions raisonnables
- Bloque les privilèges dangereux tout en autorisant les besoins applicatifs

### 2. Configuration des Pod Security Standards

**Appliquer les labels PSS au namespace :**
- `pod-security.kubernetes.io/enforce: baseline` : Politique appliquée strictement
- `pod-security.kubernetes.io/audit: baseline` : Audit des violations
- `pod-security.kubernetes.io/warn: restricted` : Avertissement pour niveau supérieur

### 3. Adaptation des déploiements pour PSS baseline

**Modifier tous les déploiements pour respecter PSS baseline :**

**Pour MySQL :**
- `runAsNonRoot: true`
- `runAsUser: 999` (utilisateur MySQL)
- `fsGroup: 999`
- `allowPrivilegeEscalation: false`
- Supprimer les capabilities non nécessaires

**Pour Ghost :**
- `runAsNonRoot: true`
- `runAsUser: 1000`
- `fsGroup: 1000`
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem` si possible

**Pour les Jobs :**
- Mêmes contraintes de sécurité
- Adaptation des scripts si nécessaire

### 4. Migration des données MySQL

**Sauvegarder et migrer les données MySQL :**
- Créer une sauvegarde complète depuis `default`
- Déployer MySQL dans `ghost-app` avec les contraintes PSS
- Restaurer les données dans le nouveau MySQL
- Vérifier l'intégrité des données

### 5. Migration de l'application Ghost

**Migrer Ghost vers `ghost-app` :**
- Adapter la configuration pour le nouveau namespace
- Modifier les variables d'environnement MySQL
- Recréer les Services (ClusterIP, NodePort sur même port 30080)
- Migrer les volumes de contenu Ghost



### 7. NetworkPolicies dans le nouveau namespace

**Recréer les NetworkPolicies dans `ghost-app` :**
- Même logique de sécurité qu'avant
- `default-deny-all` dans le nouveau namespace
- `mysql-network-policy` : MySQL accessible uniquement par Ghost
- `ghost-network-policy` : Ghost accessible depuis l'extérieur



---

## Contraintes Pod Security Standards baseline

### Sécurité requise pour tous les pods
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000  # ou 999 pour MySQL
    fsGroup: 1000    # ou 999 pour MySQL
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: container-name
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["CHOWN", "SETGID", "SETUID"]  # Seulement si nécessaire pour MySQL
      runAsNonRoot: true
```

