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
helm upgrade -i mongodb helm/mongodb -n mongodb
```

## Deploy bookinfo

```sh
helm upgrade -i bookinfo helm/bookinfo -n bookinfo --set mongodb.host=$(oc get service mongo-ingressgateway -n istio-system -o jsonpath={.status.loadBalancer.ingress[0].hostname})
```

## Deploy Istio Configurations

```sh

```

## Install the bookinfo application and basic gateway configuration to test tls origination from

```sh
cd ..
source default-vars.txt && export $(cut -d= -f1 default-vars.txt)
./install-basic-gateway-configuration.sh
```

## Verify TLS Origination from a pod within the mesh

```sh
# Test from mesh pod
oc rsh -n bookinfo -c ratings deployment/ratings-v1 curl -v http://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host})
```

Kiali should show the traffic flowing through the egress gateway.

### Helpful test commands

```sh
# Test from mesh pod
oc rsh -n bookinfo -c ratings deployment/ratings-v1 curl -v http://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host})

# Test from egressgateway
oc rsh -n istio-system-egress -c istio-proxy deployment/istio-egressgateway curl -v https://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host}) --cacert /etc/configmaps/ocp-ca-bundle/ca.crt

# show routes
istioctl pc route $(oc get pod -l app=ratings -n bookinfo -o jsonpath='{.items[0].metadata.name}') -n bookinfo --name 80 -o json

istioctl pc route $(oc get pod -l app=istio-egressgateway -n istio-system-egress -o jsonpath='{.items[0].metadata.name}') -n istio-system-egress --name http.80 -o json

# change log level
istioctl pc log $(oc get pod -l app=istio-egressgateway -n istio-system-egress -o jsonpath='{.items[0].metadata.name}') --level debug -n istio-system-egress

istioctl pc cluster $(oc get pod -l app=istio-egressgateway -n istio-system-egress -o jsonpath='{.items[0].metadata.name}') -n istio-system-egress --fqdn nginx-mesh-external.apps.cluster-a57a.a57a.sandbox1041.opentlc.com -o json
```

## Cleanup

```sh
helm delete bookinfo -n bookinfo
helm delete basic-gateway-configuration -n bookinfo
helm delete egress -n istio-system
oc delete project mesh-external istio-system bookinfo istio-system-egress
```
