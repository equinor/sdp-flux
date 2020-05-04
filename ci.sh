#! /bin/bash

if [ "$1" = "charts" ]; then
    echo "Linting custom charts"
    for chart in $(ls ./custom-charts); do
      helm lint ./custom-charts/${chart}
      if [ $? != 0 ]; then
    printf '%d\n' $? && echo "was the return code.. exiting.."
       exit 1
      fi
     done
elif [ "$1" = "kustomize" ]; then
    echo "kustomize + kubeval validation for dev cluster:"

    ./kubectl kustomize ./dev  | ./kubeval --strict --ignore-missing-schemas

    if [ $? != 0 ]; then
       printf '%d\n' $? && echo "was the return code.. exiting.."
       exit 1
      fi

    echo "kustomize + kubeval validation for prod cluster:"
    ./kubectl kustomize ./prod  | ./kubeval --strict --ignore-missing-schemas

    if [ $? != 0 ]; then
       printf '%d\n' $? && echo "was the return code.. exiting.."
       exit 1
      fi

    echo "Displaying YAML output for dev cluster:"
    ./kubectl kustomize dev/
    echo "Displaying YAML output for prod cluster:"
    ./kubectl kustomize prod/
elif [ "$1" = "manifests" ]; then
    echo "Linting K8s manifests from base only."
    # Only lint ./base because partial patches in ./prod and ./dev give false positives. 
    ./kubeval -d ./base --ignore-missing-schemas --ignored-filename-patterns flux.yaml,kustomization.yaml
      if [ $? != 0 ]; then
       printf '%d\n' $? && echo "was the return code.. exiting.."
       exit 1
      fi
else
    echo "Error: Invalid argument"
    exit 1
fi
