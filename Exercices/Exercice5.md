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



### Schéma

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                EXTERNE                                      │
│  🌍 Internet / Utilisateurs                                                │
│                                                                             │
│  💻 curl http://localhost:30080                                            │
│  🌐 curl http://ghost.local (si Ingress)                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ Port 30080 (NodePort)
                                      │ ✅ Autorisé par ingress: - {}
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLUSTER K3D                                   │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │                         NODE k3d-ghost-blog-server-0                    │ │
│ │                                                                         │ │
│ │  🔧 Service: ghost-nodeport-service                                     │ │
│ │     Type: NodePort                                                      │ │
│ │     Port: 80 → 2368                                                     │ │
│ │     NodePort: 30080                                                     │ │
│ │                                  │                                      │ │
│ │                                  │ Port 2368                            │ │
│ │                                  ▼                                      │ │
│ │  ┌─────────────────────────────────────────────────────────────────┐   │ │
│ │  │                      GHOST PODS                                 │   │ │
│ │  │  📦 ghost-pod-1        📦 ghost-pod-2                          │   │ │
│ │  │  Labels: app=ghost     Labels: app=ghost                       │   │ │
│ │  │  Port: 2368           Port: 2368                               │   │ │
│ │  │                                                                 │   │ │
│ │  │  🔒 NetworkPolicy: ghost-network-policy                        │   │ │
│ │  │  ┌─────────────────────────────────────────────────────────┐   │   │ │
│ │  │  │ INGRESS (Trafic ENTRANT)                               │   │   │ │
│ │  │  │ ✅ - {} (depuis partout)                               │   │   │ │
│ │  │  │ ✅ - from: podSelector: app=ghost (entre pods Ghost)   │   │   │ │
│ │  │  │    ports: TCP/2368                                     │   │   │ │
│ │  │  │                                                         │   │   │ │
│ │  │  │ EGRESS (Trafic SORTANT)                                │   │   │ │
│ │  │  │ ✅ → MySQL (app=mysql) port TCP/3306                   │   │   │ │
│ │  │  │ ✅ → DNS (to: {}) ports UDP/53, TCP/53                │   │   │ │
│ │  │  │ ✅ → Internet (to: {}) port TCP/443                    │   │   │ │
│ │  │  └─────────────────────────────────────────────────────────┘   │   │ │
│ │  └─────────────────────────────────────────────────────────────────┘   │ │
│ │                                  │                                      │ │
│ │                                  │ Port 3306                            │ │
│ │                                  │ ✅ Autorisé par mysql-network-policy │ │
│ │                                  ▼                                      │ │
│ │  ┌─────────────────────────────────────────────────────────────────┐   │ │
│ │  │                      MYSQL POD                                  │   │ │
│ │  │  📦 mysql-pod-0                                                 │   │ │
│ │  │  Labels: app=mysql                                              │   │ │
│ │  │  Port: 3306                                                     │   │ │
│ │  │                                                                 │   │ │
│ │  │  🔒 NetworkPolicy: mysql-network-policy                        │   │ │
│ │  │  ┌─────────────────────────────────────────────────────────┐   │   │ │
│ │  │  │ INGRESS (Trafic ENTRANT)                               │   │   │ │
│ │  │  │ ✅ SEULEMENT depuis podSelector: app=ghost             │   │   │ │
│ │  │  │    ports: TCP/3306                                     │   │   │ │
│ │  │  │ ❌ Tout autre trafic BLOQUÉ                            │   │   │ │
│ │  │  └─────────────────────────────────────────────────────────┘   │   │ │
│ │  └─────────────────────────────────────────────────────────────────┘   │ │
│ │                                                                         │ │
│ │  🔧 Service: mysql-service                                              │ │
│ │     Type: ClusterIP                                                     │ │
│ │     ClusterIP: 10.43.x.x                                                │ │
│ │     Port: 3306 → 3306                                                   │ │
│ │                                                                         │ │
│ │  🔧 Service: ghost-clusterip-service                                    │ │
│ │     Type: ClusterIP                                                     │ │
│ │     ClusterIP: 10.43.x.x                                                │ │
│ │     Port: 80 → 2368                                                     │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  🔒 NetworkPolicy: default-deny-all                                        │
│     Bloque TOUT le trafic par défaut                                       │
│     Seules les exceptions explicites sont autorisées                       │
└─────────────────────────────────────────────────────────────────────────────┘
```