
```
kubectl -n monitoring create secret generic release-aware-secrets --dry-run  \
 --from-literal=GITHUB_TOKEN=<INSERT> -o json \
 | kubeseal --format yaml --cert sealed-secret.pem > sealedsecret.yam
 ```