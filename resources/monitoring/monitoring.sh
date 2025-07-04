#!/bin/bash

# Script de déploiement K3D avec stack de monitoring
# Version corrigée avec gestion d'erreurs améliorée

set -e

# Configuration
CLUSTER_NAME="monitoring-cluster"
NAMESPACE_MONITORING="monitoring"
NAMESPACE_APP="demo-app"

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    echo_info "Vérification des prérequis..."
    
    local missing_tools=()
    
    if ! command -v k3d &> /dev/null; then
        missing_tools+=("k3d")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo_error "Outils manquants: ${missing_tools[*]}"
        echo_info "Installez ces outils avant de continuer:"
        echo "  • k3d: curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash"
        echo "  • kubectl: curl -LO https://storage.googleapis.com/kubernetes-release/release/\$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
        echo "  • helm: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
        exit 1
    fi
    
    # Vérifier que Docker fonctionne
    if ! docker ps &> /dev/null; then
        echo_error "Docker n'est pas accessible. Vérifiez que Docker est démarré et que vous avez les permissions."
        exit 1
    fi
    
    echo_success "Tous les prérequis sont satisfaits"
}

# Fonction pour nettoyer les ressources existantes
cleanup_existing() {
    echo_info "Nettoyage des ressources existantes..."
    
    # Supprimer le cluster s'il existe
    if k3d cluster list | grep -q "$CLUSTER_NAME" 2>/dev/null; then
        echo_warning "Suppression du cluster existant: $CLUSTER_NAME"
        k3d cluster delete "$CLUSTER_NAME" || true
    fi
    
    # Attendre un peu pour que les ressources soient libérées
    sleep 3
    
    echo_success "Nettoyage terminé"
}

# Fonction pour créer le cluster K3D avec configuration simplifiée
create_k3d_cluster() {
    echo_info "Création du cluster K3D..."
    
    # Configuration simple avec moins de ports pour éviter les conflits
    k3d cluster create "$CLUSTER_NAME" \
        --port "3000:3000@loadbalancer" \
        --port "9090:9090@loadbalancer" \
        --agents 1 \
        --wait \
        --timeout 5m
    
    # Vérifier que le cluster est accessible
    if ! kubectl cluster-info &> /dev/null; then
        echo_error "Impossible de se connecter au cluster"
        exit 1
    fi
    
    echo_success "Cluster K3D créé avec succès"
}

# Fonction pour créer les namespaces
create_namespaces() {
    echo_info "Création des namespaces..."
    
    kubectl create namespace "$NAMESPACE_MONITORING" --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace "$NAMESPACE_APP" --dry-run=client -o yaml | kubectl apply -f -
    
    echo_success "Namespaces créés"
}

# Fonction pour ajouter les repositories Helm
add_helm_repositories() {
    echo_info "Configuration des repositories Helm..."
    
    # Ajouter les repos avec retry
    for i in {1..3}; do
        if helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null; then
            break
        fi
        echo_warning "Tentative $i/3 pour ajouter le repo prometheus-community..."
        sleep 2
    done
    
    for i in {1..3}; do
        if helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null; then
            break
        fi
        echo_warning "Tentative $i/3 pour ajouter le repo grafana..."
        sleep 2
    done
    
    helm repo update
    
    echo_success "Repositories Helm configurés"
}

# Fonction pour déployer Prometheus (version simplifiée)
deploy_prometheus() {
    echo_info "Déploiement de Prometheus..."
    
    # Configuration simplifiée de Prometheus
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: $NAMESPACE_MONITORING
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      - job_name: 'demo-app'
        static_configs:
          - targets: ['demo-app.$NAMESPACE_APP.svc.cluster.local:80']
        metrics_path: '/metrics'
        scrape_interval: 15s
EOF

    # Déploiement Prometheus avec configuration minimale
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace "$NAMESPACE_MONITORING" \
        --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=1Gi \
        --set prometheus.prometheusSpec.retention=1d \
        --set alertmanager.enabled=false \
        --set grafana.enabled=false \
        --set kubeStateMetrics.enabled=true \
        --set nodeExporter.enabled=true \
        --set prometheus.service.type=NodePort \
        --set prometheus.service.nodePort=30090 \
        --timeout 10m \
        --wait
    
    echo_success "Prometheus déployé"
}

# Fonction pour déployer Grafana (version simplifiée)
deploy_grafana() {
    echo_info "Déploiement de Grafana..."
    
    # Créer la configuration des datasources
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: $NAMESPACE_MONITORING
  labels:
    grafana_datasource: "1"
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus-kube-prometheus-prometheus:9090
        isDefault: true
EOF

    # Déployer Grafana
    helm install grafana grafana/grafana \
        --namespace "$NAMESPACE_MONITORING" \
        --set persistence.enabled=false \
        --set service.type=NodePort \
        --set service.nodePort=30300 \
        --set adminPassword=admin123 \
        --set sidecar.datasources.enabled=true \
        --set sidecar.datasources.label=grafana_datasource \
        --timeout 10m \
        --wait
    
    echo_success "Grafana déployé"
}

# Fonction pour déployer Loki (version simplifiée)
deploy_loki() {
    echo_info "Déploiement de Loki..."
    
    helm install loki grafana/loki-stack \
        --namespace "$NAMESPACE_MONITORING" \
        --set loki.persistence.enabled=false \
        --set promtail.enabled=true \
        --set grafana.enabled=false \
        --set prometheus.enabled=false \
        --timeout 10m \
        --wait
    
    echo_success "Loki déployé"
}

# Fonction pour déployer une application d'exemple
deploy_demo_app() {
    echo_info "Déploiement de l'application d'exemple..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: $NAMESPACE_APP
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: demo-app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
        - name: nginx-config
          mountPath: /usr/share/nginx/html/metrics
          subPath: metrics
      volumes:
      - name: nginx-config
        configMap:
          name: demo-app-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-app-config
  namespace: $NAMESPACE_APP
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Demo App - Monitoring Stack</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .container { background: white; padding: 30px; border-radius: 10px; }
            h1 { color: #333; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Demo Application</h1>
            <p>Application de démonstration pour la stack de monitoring K3D.</p>
            <p><a href="/metrics">Voir les métriques</a></p>
        </div>
    </body>
    </html>
  metrics: |
    # HELP demo_requests_total Total requests
    # TYPE demo_requests_total counter
    demo_requests_total 123
    
    # HELP demo_response_time_seconds Response time
    # TYPE demo_response_time_seconds histogram
    demo_response_time_seconds_bucket{le="0.1"} 10
    demo_response_time_seconds_bucket{le="0.5"} 20
    demo_response_time_seconds_bucket{le="+Inf"} 25
    demo_response_time_seconds_sum 5.5
    demo_response_time_seconds_count 25
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: $NAMESPACE_APP
spec:
  selector:
    app: demo-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

    echo_success "Application d'exemple déployée"
}

# Fonction pour attendre que tous les pods soient prêts
wait_for_pods() {
    echo_info "Attente du démarrage des pods..."
    
    # Attendre les pods de monitoring avec timeout
    kubectl wait --for=condition=ready pod --all -n "$NAMESPACE_MONITORING" --timeout=300s || {
        echo_warning "Certains pods de monitoring ne sont pas prêts, vérification des logs..."
        kubectl get pods -n "$NAMESPACE_MONITORING"
    }
    
    # Attendre les pods de l'application
    kubectl wait --for=condition=ready pod --all -n "$NAMESPACE_APP" --timeout=60s || {
        echo_warning "L'application demo n'est pas prête, vérification..."
        kubectl get pods -n "$NAMESPACE_APP"
    }
    
    echo_success "Pods démarrés"
}

# Fonction pour configurer les port-forwards
setup_port_forwards() {
    echo_info "Configuration des port-forwards..."
    
    # Tuer les anciens port-forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Port-forward pour Grafana
    kubectl port-forward svc/grafana 3000:80 -n "$NAMESPACE_MONITORING" > /dev/null 2>&1 &
    
    # Port-forward pour Prometheus
    kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n "$NAMESPACE_MONITORING" > /dev/null 2>&1 &
    
    # Port-forward pour l'application demo
    kubectl port-forward svc/demo-app 8080:80 -n "$NAMESPACE_APP" > /dev/null 2>&1 &
    
    echo_success "Port-forwards configurés"
}

# Fonction pour afficher les informations finales
display_info() {
    echo ""
    echo "=========================================="
    echo "🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS"
    echo "=========================================="
    echo ""
    
    echo "📊 ACCÈS AUX SERVICES:"
    echo "----------------------------------------"
    echo "🔍 Prometheus : http://localhost:9090"
    echo "📈 Grafana    : http://localhost:3000"
    echo "   └── Utilisateur: admin"
    echo "   └── Mot de passe: admin123"
    echo "🚀 Demo App   : http://localhost:8080"
    echo ""
    
    echo "🔧 COMMANDES UTILES:"
    echo "----------------------------------------"
    echo "• Voir les pods        : kubectl get pods -A"
    echo "• Logs Prometheus      : kubectl logs -f -l app.kubernetes.io/name=prometheus -n $NAMESPACE_MONITORING"
    echo "• Logs Grafana         : kubectl logs -f deployment/grafana -n $NAMESPACE_MONITORING"
    echo "• Logs Demo App        : kubectl logs -f deployment/demo-app -n $NAMESPACE_APP"
    echo "• Supprimer le cluster : k3d cluster delete $CLUSTER_NAME"
    echo ""
    
    echo "📋 TROUBLESHOOTING:"
    echo "----------------------------------------"
    echo "• Si un service n'est pas accessible, vérifiez les pods:"
    echo "  kubectl get pods -n $NAMESPACE_MONITORING"
    echo "• Pour redémarrer les port-forwards:"
    echo "  pkill -f 'kubectl port-forward' && ./\$0"
    echo ""
}

# Fonction de diagnostic
run_diagnostics() {
    echo_info "Exécution des diagnostics..."
    
    echo "État du cluster:"
    kubectl cluster-info
    
    echo -e "\nNodes:"
    kubectl get nodes
    
    echo -e "\nPods dans tous les namespaces:"
    kubectl get pods -A
    
    echo -e "\nServices:"
    kubectl get svc -A
    
    echo_success "Diagnostics terminés"
}

# Fonction principale
main() {
    echo "=========================================="
    echo "🚀 DÉPLOIEMENT STACK MONITORING K3D"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    cleanup_existing
    create_k3d_cluster
    create_namespaces
    add_helm_repositories
    deploy_prometheus # statefulset, headless, serviceAccount, daemonset pour les agents
    deploy_grafana
    deploy_loki # statefulset, headless, serviceAccount pour récupérer les events, daemonset pour les agents, récupérer et parser les stdout et stderr
    deploy_demo_app
    wait_for_pods
    setup_port_forwards
    
    # Attendre que les services soient prêts
    sleep 10
    
    display_info
    run_diagnostics
    
    echo_success "🎯 Script terminé avec succès!"
}

# Fonction de nettoyage pour les signaux
cleanup_on_exit() {
    echo_warning "Nettoyage en cours..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
}

# Gestion des signaux
trap cleanup_on_exit EXIT

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi