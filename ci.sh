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
    echo "Linting K8s manifests, CRDs are ignored"
    MANIFESTS=$(find "$(pwd -P)" -not -path "*/custom-charts*" -type f \( ! -iname ".flux.yaml" \) -name "*.yaml" )  
    ./kubeval --ignore-missing-schemas $MANIFESTS
      if [ $? != 0 ]; then
       travis_terminate 1
      fi
else
    echo "Error: Invalid argument"
    exit 1
fi
