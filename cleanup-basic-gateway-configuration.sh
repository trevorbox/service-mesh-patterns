#!/bin/bash

#Define these variables in the same shell
DEPLOY_NAMESPACE=${bookinfo_namespace}

echo "Delete basic-gateway-configuration..."

helm delete basic-gateway-configuration -n ${DEPLOY_NAMESPACE}

echo "Delete bookinfo App..."

helm delete bookinfo -n ${DEPLOY_NAMESPACE}

echo "Done."

exit 0