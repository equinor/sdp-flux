#! /bin/bash

if [ "$1" = "charts" ]; then
    echo "Linting custom charts"
    for chart in $(ls ./custom-charts); do
      helm lint ./custom-charts/${chart}
      if [ $? != 0 ]; then
       travis_terminate 1
      fi
     done
elif [ "$1" = "kustomize" ]; then
    echo "Trying to build kustomize"
    ./kubectl kustomize dev/
    ./kubectl kustomize prod/
elif [ "$1" = "manifests" ]; then
    echo "Linting K8s manifests"
    STANDARD_MANIFESTS=$(find "$(pwd -P)" -not -path "*/custom-charts*" -type f \( ! -iname ".flux.yaml" \) -name *.yaml -exec grep -L -H 'apiVersion: flux.weave.works/v1beta1\|apiVersion: bitnami.com\|apiVersion: certmanager.k8s.io\|apiVersion: kustomize.config.k8s.io/v1beta1\|apiVersion: ceph.rook.io/v1' {} \;)

    ./kubeval --ignore-missing-schemas $STANDARD_MANIFESTS
      if [ $? != 0 ]; then
       travis_terminate 1
      fi
else
    echo "Error: Invalid argument"
    exit 1
fi
