#!/bin/bash

echo "Install service mesh operators..."

helm install service-mesh-operators -n openshift-operators service-mesh/service-mesh-operators/

echo "Manually approve the InstallPlans within the openshift-operators namespace at the following URL..."
echo "https://$(oc get route console -o jsonpath={.spec.host} -n openshift-console)/k8s/ns/openshift-operators/operators.coreos.com~v1alpha1~InstallPlan"

echo "Done."

exit 0