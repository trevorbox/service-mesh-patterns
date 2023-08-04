#!/bin/bash

# oc get configmap -n openshift-monitoring -o name | egrep grafana-dashboard- | while read configmap; do 
#   oc extract $configmap -n openshift-monitoring --to=helm/sre-admin-tasks/dashboards/openshift-monitoring --confirm
# done

oc get configmap -n istio-system -o name | egrep istio-grafana-configuration-dashboards- | while read configmap; do 
  oc extract $configmap -n istio-system --to=helm/grafana/dashboards/istio-system --confirm
done

exit 0