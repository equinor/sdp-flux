# Matomo helm chart

Chart for Matomo using bitnami docker image

## Kubernetes secrets

### Commands to create secrets

```bash
kubectl -n prod create secret generic matomo-db \ 
  --dry-run \
  --from-literal=mariadb-root-password=<INSERT> \
  --from-literal=mariadb-password=<INSERT> -o json \
  --from-literal=mariadb-replication-password=<INSERT> | kubeseal --format yaml --cert secret.pem > matomo-mariadb-secret.yaml
```