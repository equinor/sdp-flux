# Inject sealed-secrets private keys

```bash
kubectl config use-context k8s-cluster-prod-aks # Cluster context you want the keys from
kubectl get secret sealed-secrets-key -o yaml -n infrastructure > sealedsecrets.yaml
```

Now remove the unnecessary annotations. timesamp etc. Then apply the secret to your own cluster, and restart the pod:

```bash
kubectl config use-context <other cluster context>
kubectl apply -f sealedsecrets.yaml
kubectl delete pod -n infrastructure sealed-secret
rm sealedsecrets.yaml
```
