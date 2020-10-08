# multiple cluster trust

```sh
oc new-project istio-system
oc new-project istio-system-egress
oc new-project istio-system2
oc new-project istio-system-egress2
oc new-project cert-manager
oc new-project bookinfo
oc new-project mongodb

helm upgrade -i istio-system-control-plane -n istio-system helm/istio-system-control-plane
# wait for cp to finish installing then enable the egressgateway
helm upgrade -i istio-system-control-plane -n istio-system helm/istio-system-control-plane --values values-istio-system-egressgateway-enabled.yaml

helm upgrade -i istio-system2-control-plane -n istio-system helm/istio-system2-control-plane
```

Deploy cert-manager (skip if already present in the cluster)

```shell
oc apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.0/cert-manager.yaml
```

Deploy local root and intermeadiate CAs

```shell
helm upgrade -i cert-manager -n istio-system helm/cert-manager

oc delete secret istio-ca-secret -n istio-system

helm upgrade -i rootca helm/install-istio-ca-secret -n istio-system \
  --set rootca.tls_crt=$(oc get secret rootca -n istio-system -o jsonpath='{.data.tls\.crt}') \
  --set rootca.tls_key=$(oc get secret rootca -n istio-system -o jsonpath='{.data.tls\.key}')

oc rollout restart deployment -n istio-system # restart everything to use the new rootca

oc delete secret istio-ca-secret -n istio-system2

helm upgrade -i rootca helm/install-istio-ca-secret -n istio-system2 \
  --set rootca.tls_crt=$(oc get secret rootca -n istio-system -o jsonpath='{.data.tls\.crt}') \
  --set rootca.tls_key=$(oc get secret rootca -n istio-system -o jsonpath='{.data.tls\.key}')

oc rollout restart deployment -n istio-system2 # restart everything to use the new rootca

```

## Install mongodb in istio-system2

```sh
helm upgrade -i mongodb helm/mongodb -n mongodb --set mongodb.host=$(oc get service mongo-ingressgateway -n istio-system2 -o jsonpath={.status.loadBalancer.ingress[0].hostname})
```

## Install bookinfo in istio-system

```sh
helm upgrade -i bookinfo helm/bookinfo -n bookinfo \
  --set mongodb.host=$(oc get service mongo-ingressgateway -n istio-system2 -o jsonpath={.status.loadBalancer.ingress[0].hostname}) \
  --set control_plane.ingressgateway.host=$(oc get route api -n istio-system -o jsonpath={'.spec.host'})
```
