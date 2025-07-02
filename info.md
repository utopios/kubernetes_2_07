#### Nom des images OCI
nginx:1.20 => localhost:500/nginx:1.20

### Création du pod nginx
kubectl apply -f resources/pod.yml
kubectl get pods 
kubectl describe pods <nom_pod>
### Port forward
kubectl port-forward pods/<nom_pod> [port_host]:[Port_pod]
