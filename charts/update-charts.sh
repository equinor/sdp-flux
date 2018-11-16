#!/bin/bash

set -e
helm repo update

CHARTS="stable/nginx-ingress stable/external-dns stable/cert-manager stable/prometheus-operator"

for chart in $CHARTS; do
  helm fetch $chart --untar --devel
done

git add . && git commit -m"update charts"
