# TLS origination using a trusted ca certificate

For this configuration to work we need to deploy the Egress Gateway into a separate namespace dedicated just for the Egress Gateway. This is because we need to mount our own CA Certificate to the proxy pod and create a DestinationRule just for the Egress Gateway proxy.

## Create root ca secret within egress gateway namespace

```sh
oc new-project istio-system
oc new-project istio-system-egress
oc new-project mongodb
oc new-project bookinfo

oc get secrets -n openshift-ingress-operator router-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca.crt
oc create secret generic ocp-ca-bundle --from-file=/tmp/ca.crt -n istio-system-egress
```

## Install the control plane

> Note: If installing for the first time, you may get a `Error: admission webhook "smcp.validation.maistra.io" denied the request: gateways.istio-egressgateway.namespace=istio-system-egress is not allowed: namespace must be part of the mesh`
>
> To fix this:
>
> 1. Comment out the spec.istio.gateways.istio-egressgateway section within the egressgateway-tls-origination-trusted-ca/templates/control-plane/servicemeshcontrolplane-basic-install.yaml file
> 2. Run the help upgrade shown below
> 3. Wait for the control plane to finish deploying
> 4. Uncomment the spec.istio.gateways.istio-egressgateway section and rerun the helm upgrade

```sh
helm upgrade -i control-plane -n istio-system helm/control-plane
```

Wait for the control plane to install.

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
