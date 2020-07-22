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

MONGODB_HOST=$(oc get service mongo-ingressgateway -n ${CONTROL_PLANE_NAMESPACE} -o jsonpath={.status.loadBalancer.ingress[0].hostname})
MONGODB_IP=$(host $MONGODB_HOST | grep " has address " | cut -d" " -f4 | head -n 1)
EGRESSGATEWAY_PORT=$(oc get svc istio-egressgateway -n ${CONTROL_PLANE_NAMESPACE} -o jsonpath={.spec.ports[0].port})

echo "MONGODB_HOST: ${MONGODB_HOST}"
echo "MONGODB_IP: ${MONGODB_IP}"
echo "EGRESSGATEWAY_PORT: ${EGRESSGATEWAY_PORT}"

helm install mongo-egressgateway-configuration -n ${MONGODB_NAMESPACE} \
  --set control_plane_namespace=${CONTROL_PLANE_NAMESPACE} \
  --set control_plane_name=${CONTROL_PLANE_NAME} \
  --set mongodb.host=$(oc get service mongo-ingressgateway -n ${CONTROL_PLANE_NAMESPACE} -o jsonpath={.status.loadBalancer.ingress[0].hostname}) \
  --set route_hostname=$(oc get route ${CONTROL_PLANE_ROUTE_NAME} -n ${CONTROL_PLANE_NAMESPACE} -o jsonpath={'.spec.host'}) \
  --set mongodb_ip=${MONGODB_IP} \
  --set egressgateway_port=${EGRESSGATEWAY_PORT} \
  mongo-egressgateway-configuration

echo "Install mongodb apps..."

helm install mongodb -n ${MONGODB_NAMESPACE} \
  --set mongodb.host=$(oc get service mongo-ingressgateway -n ${CONTROL_PLANE_NAMESPACE} -o jsonpath={.status.loadBalancer.ingress[0].hostname}) \
  mongodb

echo "Done."

exit 0