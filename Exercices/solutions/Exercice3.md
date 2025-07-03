# Exercice 3 – Déployer PostgreSQL avec stockage persistant dans Kubernetes


Un développeur souhaite tester un script qui insère des données dans une base PostgreSQL. Il veut s’assurer que la base **ne perd pas les données** après un `kubectl delete pod`.

---

## Instructions

1. **Créer un cluster k3d** (si ce n’est pas encore fait).

2. **Vérifier qu’une `StorageClass` de type `local-path` est disponible**.

3. **Créer un `PersistentVolumeClaim` dynamique** de 1Gi utilisant cette `StorageClass`.

4. **Déployer un Pod PostgreSQL** :

   * Image : `postgres:15`
   * Variables d’environnement :

     * `POSTGRES_USER=demo`
     * `POSTGRES_PASSWORD=demo`
     * `POSTGRES_DB=testdb`
   * Le volume monté doit pointer vers `/var/lib/postgresql/data`
   * Le PVC doit être utilisé pour stocker les données

5. **Se connecter à la base** via `kubectl exec` et psql :

   * Créer une table simple : `CREATE TABLE demo (id SERIAL, value TEXT);`
   * Insérer quelques valeurs

6. **Supprimer le Pod PostgreSQL** (pas le PVC) et le recréer avec le même YAML

7. **Se reconnecter et vérifier que les données sont toujours présentes**

