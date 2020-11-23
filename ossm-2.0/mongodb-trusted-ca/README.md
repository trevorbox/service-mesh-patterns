# TLS origination using a trusted ca certificate

For this configuration to work we need to deploy the Egress Gateway into a separate namespace dedicated just for the Egress Gateway. This is because we need to mount our own CA Certificate to the proxy pod and create a DestinationRule just for the Egress Gateway proxy.

## Setup

```sh
oc new-project istio-system
oc new-project istio-system-egress
oc new-project mongodb
oc new-project bookinfo
```

## Install the control plane

> Note: When installing for the first time, you need to first install without the egress gateway enabled since the validation on the istio-system-egress namespace will fail and not progress. Once the control plane is up the egress gateway may be enabled.

```sh
helm upgrade -i control-plane -n istio-system helm/control-plane --set gateways.egress.enabled=false
helm upgrade -i control-plane -n istio-system helm/control-plane --reset-values
```

Wait for the control plane to install.

## Add the mongo proxy ca to egressgateway

```sh
oc get secrets -n istio-system mongo-proxy-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca.crt

oc create secret generic ocp-ca-bundle --from-file=/tmp/ca.crt -n istio-system-egress
```

## Deploy mongodb

```sh
helm upgrade -i mongodb helm/mongodb -n mongodb --set mongodb.host=$(oc get service mongo-ingressgateway -n istio-system -o jsonpath={.status.loadBalancer.ingress[0].hostname})
```

## Configure mongodb

Wait for the mongodb-v1 pod to run before running the setup script.

This will create the test database bookinfo rating-v2 service will connect to.

```sh
./ingress-mongodb-setup-tls.sh
```

## Deploy bookinfo

```sh
helm upgrade -i bookinfo helm/bookinfo -n bookinfo \
  --set mongodb.host=$(oc get service mongo-ingressgateway -n istio-system -o jsonpath={.status.loadBalancer.ingress[0].hostname}) \
  --set control_plane.ingressgateway.host=$(oc get route api -n istio-system -o jsonpath={'.spec.host'})
```

### Verify traffic flows through the egressgateway

Open the following url in a web browser.

```sh
echo "https://$(oc get route api -n istio-system -o jsonpath={'.spec.host'})/productpage"
```
