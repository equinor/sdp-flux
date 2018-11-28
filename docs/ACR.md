# How to use Azure Container Registry in context of SDP
In this document we try to go through the usuall process of how to set up, deploy and manage a Docker image to Kubernetes production.

## Overview
In short we use this process to deploy containers.

Create app -> Dockerize app -> Test -> Push to ACR -> Create Helm chart for staging -> Push to staging -> Push to prod

This process is a bit fluid as we use a few different repositories, test environments, CI and other processes that needs to be supported but the principle follows this process. In this document we will describe the LEP (least effort process).

## The different stages
On to the stages

### Create app
In this demo situation all I want is to create a homepage that displays "Hello World" from a nginx container. Create a folder and initialize a Git repository, remember to push this to GitLab or GitHub. We create a file named `index.html` and put this inside.

```
<html>
<head><title>Hello World</title>
<body>Hello World!</body>
</html>
```
I can not call this an App, but this is a very basic example.

Remember to commit.

### Dockerize app
In the same folder as the index.html-file create a file called `Dockerfile` and put this inside

```
FROM nginx:mainline-alpine
RUN rm -rf /usr/share/nginx/html/*
ADD index.html /usr/share/nginx/html/
```

We use the Nginx Alpine container image, cleans out the default html folder and adds the index file.

Build the image `docker build -t nginx-hello-world .`

Remember to commit.

### Test
Just run the image and browse to see if this works as planned

- Run `docker run -p 8080:80 nginx-hello-world`
- Go to http://localhost:8080

If the page shows "Hello World!" you have succeded!

### Push to Azure Container Registry
As a member of the SDP Tools team you should have permissions to the ACR, what you need is the name of the ACR and the resource group that holds the ACR. In this case let us assume the ACR is named sdpAcr and the resource group is sdpAcrRg. We also asume you have Azure-Cli installed.

- Log in to Azure
  `az login`

- Get the docker registry credentials
  `az acr login --name sdpAcr`

- Get the ACR URL
  `az acr list --resource-group sdpAcrRg --query "[].{acrLoginServer:loginServer}" --output table` (we assume sdpacr.azurecr.io)

- Tag the container image to remote registry
  `docker tag nginx-hello-world sdpacr.azurecr.io/nginx-hello-world:rc-$(git log -1 --pretty=%h)`

- Push the container to remote registry
  `docker push sdpacr.azurecr.io/nginx-hello-world:rc-$(git log -1 --pretty=%h)`

- Make sure the image has been pushed
  `az acr repository show-tags --name sdpAcr --repository nginx-hello-world --output table`

### Create Helm chart for staging
Go to custom-charts folder under your local sdp-flux repository and create a new branch. After the new branch is created you can start with a fresh Helm chart.

- Create a Helm chart
  `helm create nginx-hello-world`

- The chart creates a deployment, a service and a ingress. This is what we want, we just need to adjust a few things. Start with going in to the new helm directory.

- Edit the Chart.yaml file to match your preferences and add a new value (pullSecret) to `values.yaml`. At the top of the file make it look like this;
```
image:
  repository: sdpacr.azurecr.io/nginx-hello-world
  tag: latest
  pullPolicy: IfNotPresent
  pullSecret: ""
```

- The next thing we need to edit is the file `templates/deployment.yaml`. In this want to add imagePullSecrets section to spec. Make it look like this
```
          resources:
{{ toYaml .Values.resources | indent 12 }}
      imagePullSecrets:
        - name: {{ .Values.image.pullSecret }}
```

The Helm chart for this super simple app is complete and we can push this to the cluster.

### Push to staging
Our method of pushing this to the cluster is to create HelmRelease for the image.

- As we are starting with the staging namespace we create a file under `releases/staging` named `hr-nginx-hello-world.yaml` with this content.

```
---
apiVersion: flux.weave.works/v1beta1
kind: HelmRelease
metadata:
  name: nginx-hello-world-staging
  namespace: staging
  annotations:
    flux.weave.works/automated: "true"
    flux.weave.works/tag.chart-image: glob:rc-*
spec:
  chart:
    git: git@github.com:Statoil/sdp-flux.git # This must be the sdp-flux repo
    ref: master
    path: custom-charts/nginx-hello-world # Change this path if apropriate
  values:
    image: 
      # repository: sdpacr.azurecr.io/nginx-hello-world # Should not be needed as you set this as default in values.yaml
      tag: rc-3df9d9b # This is the tag you pushed earlier
      pullSecret: registry-sdpacr # This has to be the secret where docker registry information is stored
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
        kubernetes.io/tls-acme: "true"
        external-dns.alpha.kubernetes.io/hostname: helloworld.stg.sdp.equinor.com.
      hosts:
      - helloworld.stg.sdp.equinor.com
      tls:
      - secretName: helloworld-stg-tls
        hosts:
        - helloworld.stg.sdp.equinor.com
```

- Make sure you have the container registry secret populated before you run this on the cluster. You can upload the secret by modifying this command
  `kubectl -n NAMESPACE create secret docker-registry SECRET_NAME --docker-server=REGISTRY_URL --docker-username=SERVICE_PRINCIPAL_ID --docker-password=SERVICE_PRINCIPAL_PASSWORD --docker-email=gm_sds_rdi@equinor.com`

- Commit the changes, push to remote and create a pull request. When this is merged to master the cluster should update and create a new HelmRelease named nginx-hello-world-staging.

- In this situation you can update the container multiple times with new rc-GIT tag to update and fix issues before it is pushed to prod.

### Push to prod

This is a task that can further be disected down in smaller parts. We start with copying the HelmRelease to prod and commiting this to the branch and doing a pull request. Next we tag the docker image with a version that is matching the HelmRelease and pushes this to ACR.

- Copy `releases/staging/hr-nginx-hello-world` to `releases/prod/hr-nginx-hello-world` and edit it to match this
```
---
apiVersion: flux.weave.works/v1beta1
kind: HelmRelease
metadata:
  name: nginx-hello-world
  namespace: staging
  annotations:
    flux.weave.works/automated: "true"
    flux.weave.works/tag.chart-image: semver:~0.1 # This will automatically update the image from 0.1.0 to 0.1.1 and so on
spec:
  chart:
    git: git@github.com:Statoil/sdp-flux.git # This must be the sdp-flux repo
    ref: master
    path: custom-charts/nginx-hello-world # Change this path if apropriate
  values:
    image: 
      # repository: sdpacr.azurecr.io/nginx-hello-world # Should not be needed as you set this as default in values.yaml
      tag: 0.1.0 # This is the tag you pushed earlier
      pullSecret: registry-sdpacr # This has to be the secret where docker registry information is stored
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
        kubernetes.io/tls-acme: "true"
        external-dns.alpha.kubernetes.io/hostname: helloworld.sdp.equinor.com.
      hosts:
      - helloworld.sdp.equinor.com
      tls:
      - secretName: helloworld-tls
        hosts:
        - helloworld.sdp.equinor.com
```

- Commit this to the branch, push to remote and create a pull request

- Create the docker registry secret if it does not exist

- Tag the latest docker image to version 0.1.0
  `docker tag nginx-hello-world sdpacr.azurecr.io/nginx-hello-world:0.1.0`

- Push the docker image to the registry
  `docker push sdpacr.azurecr.io/nginx-hello-world:0.1.0`