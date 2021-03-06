#!/bin/bash

DEPLOY_NAMESPACE=${control_plane_namespace}

echo "Delete control plane..."

helm delete control-plane-mongodb -n ${DEPLOY_NAMESPACE}

echo "Done."

exit 0