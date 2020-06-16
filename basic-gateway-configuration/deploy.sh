#!/bin/bash

DEPLOY_NAMESPACE=bookinfo
CONTROL_PLANE_NAMESPACE=istio-system
CONTROL_PLANE_NAME=basic-install
CONTROL_PLANE_ROUTE_NAME=api

oc new-project ${DEPLOY_NAMESPACE}

echo "Deploy VirtualService & App in namespace \"${DEPLOY_NAMESPACE}\" and Gateway in namespace \"${CONTROL_PLANE_NAMESPACE}\"..."
helm template -n ${DEPLOY_NAMESPACE} \
  --set control_plane_namespace=${CONTROL_PLANE_NAMESPACE} \
  --set control_plane_name=${CONTROL_PLANE_NAME} \
  --set route_hostname=$(oc get route ${CONTROL_PLANE_ROUTE_NAME} -n ${CONTROL_PLANE_NAMESPACE} -o jsonpath={'.spec.host'}) \
  . | oc apply -f -

echo "Done."
exit 0