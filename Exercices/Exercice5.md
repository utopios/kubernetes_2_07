# Exercice 5– Sécuriser Ghost avec NetworkPolicies

À partir de la solution Ghost fonctionnelle (ClusterIP + NodePort), l'équipe sécurité demande d'implémenter des NetworkPolicies pour contrôler et sécuriser les communications réseau entre les composants.

---

## Contexte de sécurité

L'équipe sécurité a identifié que **par défaut, tous les pods peuvent communiquer entre eux** dans Kubernetes. Pour respecter le principe de **moindre privilège**, vous devez implémenter des NetworkPolicies qui :

1. **Bloquent tout le trafic par défaut**
2. **Autorisent uniquement les communications nécessaires**
3. **Protègent MySQL contre les accès non autorisés**
4. **Permettent l'accès externe à Ghost uniquement**

---

## Prérequis

Vous devez avoir la solution Ghost fonctionnelle avec :
- MySQL déployé avec service ClusterIP
- Ghost déployé avec services ClusterIP et NodePort
- Accès à Ghost via `http://localhost:30080`

---

## Architecture de sécurité cible

```
┌─────────────────────────────────────────────────────────┐
│                      EXTERNE                            │
│  ✅ http://localhost:30080  → Ghost NodePort            │
│  ❌ Tout autre accès bloqué                             │
└─────────────────────────────────────────────────────────┘
                                │ (autorisé)
┌─────────────────────────────────────────────────────────┐
│                GHOST APPLICATION                        │
│  ✅ Reçoit trafic externe (NodePort)                   │
│  ✅ Peut accéder à MySQL                               │
│  ❌ Ne peut PAS accéder à d'autres services            │
└─────────────────────────────────────────────────────────┘
                                │ (autorisé)
┌─────────────────────────────────────────────────────────┐
│                 MYSQL DATABASE                          │
│  ✅ Reçoit connexions de Ghost uniquement              │
│  ❌ BLOQUE tout autre trafic                           │
│  ❌ Pas d'accès externe                                │
└─────────────────────────────────────────────────────────┘
```

---


### 2. Implémenter une NetworkPolicy "Deny All"

**Créer une politique par défaut qui bloque tout le trafic :**
- Nom : `default-deny-all`
- Effet : Bloquer tout le trafic entrant (Ingress)
- Portée : Tous les pods du namespace default

### 3. Créer une NetworkPolicy pour MySQL

**Politique pour MySQL :**
- Nom : `mysql-network-policy`
- Autoriser le trafic entrant uniquement depuis les pods Ghost
- Port autorisé : 3306
- Protocole : TCP

### 4. Créer une NetworkPolicy pour Ghost

**Politique pour Ghost :**
- Nom : `ghost-network-policy`
- Autoriser le trafic entrant depuis :
  - L'extérieur (pour NodePort)
  - Les autres pods Ghost (pour ClusterIP)
- Port autorisé : 2368
- Protocole : TCP

### 5. Créer une NetworkPolicy pour les sorties de Ghost

**Politique pour les sorties de Ghost :**
- Nom : `ghost-egress-policy`
- Autoriser Ghost à accéder à :
  - MySQL (port 3306)
  - DNS (port 53)
  - Internet pour les mises à jour (optionnel)

