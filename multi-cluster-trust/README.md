# multiple cluster trust

This demonstrates mTLS using a common rootca between two different control planes. mTLS is originated from the istio-system egressgateway to the istio-system2 mongo-ingressgateway.

> TODO with this configuration TLS origination should be possible from just the sidecar (no egressgateway needed)

## Setup

```sh
oc new-project istio-system
oc new-project istio-system-egress
oc new-project istio-system2
oc new-project cert-manager
oc new-project bookinfo
oc new-project mongodb
```

## Deploy cert-manager (skip if already present in the cluster)

```shell
oc apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.0/cert-manager.yaml
```

## Deploy local root CA to both control planes

```shell
helm upgrade -i cert-manager -n istio-system helm/cert-manager

helm upgrade -i rootca helm/install-cacerts -n istio-system \
  --set rootca.tls_crt=$(oc get secret rootca -n istio-system -o jsonpath='{.data.tls\.crt}') \
  --set rootca.tls_key=$(oc get secret rootca -n istio-system -o jsonpath='{.data.tls\.key}')

helm upgrade -i rootca helm/install-cacerts -n istio-system2 \
  --set rootca.tls_crt=$(oc get secret rootca -n istio-system -o jsonpath='{.data.tls\.crt}') \
  --set rootca.tls_key=$(oc get secret rootca -n istio-system -o jsonpath='{.data.tls\.key}')
```

## Install control planes using common root cacerts

```sh
helm upgrade -i istio-system-control-plane -n istio-system helm/istio-system-control-plane
# wait for cp to finish installing then enable the egressgateway
helm upgrade -i istio-system-control-plane -n istio-system helm/istio-system-control-plane --values values-istio-system-egressgateway-enabled.yaml

helm upgrade -i istio-system2-control-plane -n istio-system2 helm/istio-system2-control-plane
```

## Install mongodb in istio-system2

```sh
helm upgrade -i mongodb helm/mongodb -n mongodb --set mongodb.host=$(oc get service mongo-ingressgateway -n istio-system2 -o jsonpath={.status.loadBalancer.ingress[0].hostname})
```

## Manually create user and add ratings data from the mongodb pod terminal

```sh
mongo -u admin -p redhat --authenticationDatabase admin
use test
db.createUser(
   {
     user: "bookinfo",
     pwd: "redhat",
     roles: [ "read"]
   }
);
db.ratings.insert(
  [{rating: 1}]
);
db.ratings.find({});
```

## Install bookinfo in istio-system

```sh
helm upgrade -i bookinfo helm/bookinfo -n bookinfo \
  --set mongodb.host=$(oc get service mongo-ingressgateway -n istio-system2 -o jsonpath={.status.loadBalancer.ingress[0].hostname}) \
  --set control_plane.ingressgateway.host=$(oc get route api -n istio-system -o jsonpath={'.spec.host'})
```

## Verify traffic flows through the egressgateway

Open the following url in a web browser. If you get the ratings star its works.

```sh
echo "https://$(oc get route api -n istio-system -o jsonpath={'.spec.host'})/productpage"
```

## Helpful test commands

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

istioctl pc log $(oc get pod -l app=istio-egressgateway -n istio-system-egress -o jsonpath='{.items[0].metadata.name}') --level debug -n istio-system-egress

istioctl pc cluster $(oc get pod -l app=istio-egressgateway -n istio-system-egress -o jsonpath='{.items[0].metadata.name}') -n istio-system-egress --fqdn nginx-mesh-external.apps.cluster-a57a.a57a.sandbox1041.opentlc.com -o json
```

## Misc

```sh
SECRETS=$(oc get secrets -n istio-system -o name | egrep 'istio\.')
for s in $SECRETS; do oc delete $s -n istio-system; done
```
