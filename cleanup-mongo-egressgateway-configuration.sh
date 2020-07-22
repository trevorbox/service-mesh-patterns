#!/bin/bash

#Define these variables in the same shell
DEPLOY_NAMESPACE=${mongodb_namespace}

echo "Delete gateway configuration..."

helm delete mongo-egressgateway-configuration -n ${DEPLOY_NAMESPACE}

echo "Delete apps..."

helm delete mongodb -n ${DEPLOY_NAMESPACE}

echo "Done."

exit 0