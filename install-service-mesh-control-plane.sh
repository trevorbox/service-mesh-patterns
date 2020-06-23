#!/bin/bash

DEPLOY_NAMESPACE=${control_plane_namespace}

oc new-project ${DEPLOY_NAMESPACE}

echo "Install control plane..."

helm install control-plane -n ${DEPLOY_NAMESPACE} service-mesh/control-plane/

echo "Wait for control plane to finish deployment..."

FAILURES=0
RETRY=10
for ((i=$RETRY; i>=1; i--)); do if [ -z "$(oc get servicemeshcontrolplane ${control_plane_name} -n ${DEPLOY_NAMESPACE} -o jsonpath={'.status.annotations.readyComponentCount'})" ]; then echo "wait $i more times for service mesh deployment..."; (( FAILURES++ )); sleep 30s; else echo "service mesh deployed successfully!"; break; fi; done

#exit with failure if the mesh failed to deploy
if [ $FAILURES -ge $RETRY ]; then echo "Deploying the control plane took longer than expected. Check The status of it."; exit 1; fi

echo "Done."
exit 0