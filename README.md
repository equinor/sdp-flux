# Repository used for Kubernetes GitOps
This is the repository where we define the manifest to be run in Kubernetes. We use [Flux](https://github.com/weaveworks/flux) as the basis for our GitOps workflow.

## How it works
In essence we create manifest to be run on the Kubernetes cluster, commit them to this repository and then the Flux controller notices the new commit and applies all the YAML files (can be simplified down to `kubectl -f FILENAME`).

## How we use it
In production we never commit straight to the repository, always create a new branch (or use your existing) (`git branch -b new_branch_name`) modify what you want changed or implement your new feature, commit (`git add . && git commit -m 'commit message'`) and then push to remote (`git push -u origin new_branch_name`). After all this editing, commit and pushing you need to create a pull-request so that you, but preferably another on your team can see review the changes and merge the files.

__TODO__: Find a procedure for testing the code before commiting and running on prod.

## Tips and tricks
How to do something we do a lot? If you know, type them up here and we shall all be the wiser for it.

### Produce certificates from ingress config (Cert Manager)
As we use [Cert Manager](https://github.com/jetstack/cert-manager) for creating, validating and deploying Lets Encrypt certificates we can shortcut the usuall procedure of creating a Certificate resource and then referencing the secret from this Certificate in the ingress with adding a few annotations to the ingress.

In the shortest terms add these [annotations to your ingress](http://docs.cert-manager.io/en/latest/reference/ingress-shim.html#supported-annotations) (and update tls-config as well)

```
kubernetes.io/ingress.class: nginx
kubernetes.io/tls-acme: "true"
```

This works because we have defined a default issuer and protocol when we deployed [Cert Manager](releases/infrastructure/fhr-cert-manager.yaml).

### Automaticly create DNS entries (External DNS)
We have implemented External DNS with the Kubernetes cluster and connected it to the Azure DNS Zone. This is done with a Azure AD Service Principal that has rights to only change this DNS Zone.

[External DNS](https://github.com/kubernetes-incubator/external-dns) updates DNS Zone entries with the help of annotations on ingress (or loadbalancer) resoources. To create and update a DNS entry use the following annotation

```
external-dns.alpha.kubernetes.io/hostname: demo.example.com.
```

### Full example using Cert Manager and External DNS
This example manifest uses the techniques in the two previous sections and shows how these works together to automate some tedious tasks.

```
---
apiVersion: helm.integrations.flux.weave.works/v1alpha2
kind: FluxHelmRelease
metadata:
  name: sdp-demo
  namespace: prod
  labels:
    chart: sdp-demo
  annotations:
    flux.weave.works/automated: "true"
spec:
  chartGitPath: sdp-demo
  releaseName: sdp-demo
  values:
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
        kubernetes.io/tls-acme: "true"
        external-dns.alpha.kubernetes.io/hostname: demo.example.com.
      hosts:
      - demo.example.com
      tls:
      - secretName: demo-tls
        hosts:
        - demo.example.com
```