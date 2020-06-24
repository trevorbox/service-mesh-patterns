#!/bin/bash

#Define these variables in the same shell
MONGODB_NAMESPACE=${mongodb_namespace}
BOOKINFO_NAMESPACE=${bookinfo_namespace}
CONTROL_PLANE_NAMESPACE=${control_plane_namespace}
CONTROL_PLANE_NAME=${control_plane_name} 
CONTROL_PLANE_ROUTE_NAME=${control_plane_route_name}

oc new-project ${MONGODB_NAMESPACE}
oc new-project ${BOOKINFO_NAMESPACE}

echo "Install mongo gateway configuration..."

helm install mongo-gateway-configuration -n ${MONGODB_NAMESPACE} \
  --set control_plane_namespace=${CONTROL_PLANE_NAMESPACE} \
  --set control_plane_name=${CONTROL_PLANE_NAME} \
  --set mongodb.host=$(oc get service mongo-ingressgateway -n ${CONTROL_PLANE_NAMESPACE} -o jsonpath={.status.loadBalancer.ingress[0].hostname}) \
  --set route_hostname=$(oc get route ${CONTROL_PLANE_ROUTE_NAME} -n ${CONTROL_PLANE_NAMESPACE} -o jsonpath={'.spec.host'}) \
  mongo-gateway-configuration

echo "Install mongodb apps..."

helm install mongodb -n ${MONGODB_NAMESPACE} \
  --set mongodb.host=$(oc get service mongo-ingressgateway -n ${CONTROL_PLANE_NAMESPACE} -o jsonpath={.status.loadBalancer.ingress[0].hostname}) \
  mongodb

echo "Done."

exit 0