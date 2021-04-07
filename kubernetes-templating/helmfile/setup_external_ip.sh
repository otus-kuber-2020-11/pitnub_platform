#!/bin/bash

ingrip=$(kubectl get svc -n ingress-nginx | grep LoadBalancer | awk '{print($4)}')
sed "s/harbor.IP.nip.io/harbor.$ingrip.nip.io/" values_wout_ip.yaml > values.yaml
