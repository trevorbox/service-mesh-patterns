#!/bin/bash

#Define these variables in the same shell
DEPLOY_NAMESPACE=${deploy_namespace}
CONTROL_PLANE_NAMESPACE=${control_plane_namespace}
CONTROL_PLANE_NAME=${control_plane_name}
CONTROL_PLANE_ROUTE_NAME=${control_plane_route_name}

oc new-project ${DEPLOY_NAMESPACE}

echo -e "\nDeploy VirtualService & bookinfo App in namespace \"${DEPLOY_NAMESPACE}\" and Gateway in namespace \"${CONTROL_PLANE_NAMESPACE}\"...\n"

helm template basic-gateway-configuration -n ${DEPLOY_NAMESPACE} \
  --set control_plane_namespace=${CONTROL_PLANE_NAMESPACE} \
  --set control_plane_name=${CONTROL_PLANE_NAME} \
  --set route_hostname=$(oc get route ${CONTROL_PLANE_ROUTE_NAME} -n ${CONTROL_PLANE_NAMESPACE} -o jsonpath={'.spec.host'}) \
  | oc apply -f -

echo -e "\nDeploy bookinfo App...\n"

helm template bookinfo -n ${DEPLOY_NAMESPACE} | oc apply -f -

echo -e "\nDone.\n"

exit 0