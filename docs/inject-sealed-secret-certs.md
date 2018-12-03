### Inject sealed secrets keys to your own cluster

```
kubectl config use-context k8s-cluster-prod-aks # Cluster context you want the keys from
kubectl get secret sealed-secrets-key -o yaml -n infrastructure > sealedsecrets.yaml
```

Now remove the unnecessary annotations. timesamp etc. Then apply the secret to your own cluster:

```
kubectl config use-context <other cluster context>
kubectl apply -f sealedsecrets.yaml
rm sealedsecrets.yaml
```