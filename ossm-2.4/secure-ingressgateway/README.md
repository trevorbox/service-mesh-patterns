# Secure Ingress Gateway

This example demonstrates an Openshift passthrough route to an ingress gateway that presents a cert-manager certificate using SDS.

## Install Operators

```sh
oc adm new-project openshift-operators-redhat
oc adm new-project openshift-distributed-tracing
oc new-project cert-manager-operator
helm upgrade -i service-mesh-operators -n openshift-operators helm/service-mesh-operators --create-namespace
```

## Setup

```sh
export istio_system_namespace=istio-system
export istio_ingress_namespace=istio-ingress
```

## Create certificate for ingressgateway

```sh
helm upgrade -i --create-namespace -n ${istio_ingress_namespace} cert-manager-certs helm/cert-manager --set ingressgateway.cert.commonName=api-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})
```

## Install Control Plane

```sh
helm upgrade --create-namespace -i control-plane -n ${istio_system_namespace} helm/control-plane
```

## Helmchart for istio gateway injection

```sh
# Taken from...
# helm repo add istio https://istio-release.storage.googleapis.com/charts
# helm repo update
# helm install istio-ingressgateway istio/gateway -n istio-ingress
helm upgrade -i istio-ingressgateway helm/injected-gateway -n ${istio_ingress_namespace}
```

## Install Bookinfo Istio Configs

```sh
helm upgrade --create-namespace -i bookinfo-istio helm/bookinfo-istio -n bookinfo --set ingressgateway.host=$(oc get route api -n ${istio_ingress_namespace} -o jsonpath={'.spec.host'})
```

## Install Bookinfo

```sh
helm upgrade --create-namespace -i bookinfo helm/bookinfo -n bookinfo
```

## Install nginx-echo-headers Istio Configs

```sh
helm upgrade --create-namespace -i nginx-echo-headers-istio helm/nginx-echo-headers-istio -n nginx-echo-headers
```

## Install nginx-echo-headers

```sh
helm upgrade --create-namespace -i nginx-echo-headers helm/nginx-echo-headers -n nginx-echo-headers
```

## Test nginx-echo-headers

```sh
curl -ik https://api-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})/nginx-echo-headers
```

## Install golang-ex Istio Configs

```sh
helm upgrade --create-namespace -i golang-ex-istio helm/golang-ex-istio -n golang-ex
```

## Install golang-ex

```sh
helm upgrade --create-namespace -i golang-ex helm/golang-ex -n golang-ex
```

## Test golang-ex

```sh
curl -ik https://api-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})/golang-ex
```

## user monitoring

<https://61854--docspreview.netlify.app/openshift-enterprise/latest/service_mesh/v2x/ossm-observability.html#ossm-integrating-with-user-workload-monitoring_observability>

This solution includes custom kiali configuration to use openshift-monitoring prometheus.
TODO: Grafana should use openshift prometheus as well, however authentication options are limited for GrafanaDataSources.

```sh
oc apply -f configmap-cluster-monitoring-config.yaml -n openshift-monitoring
helm upgrade --create-namespace -i control-plane -n ${istio_system_namespace} helm/control-plane -f helm/control-plane/values-user-monitoring.yaml
helm upgrade -i user-workload-monitoring helm/user-workload-monitoring -n ${istio_system_namespace}
```

testing prometheus auth notes...

```sh
export token=
curl -G -s -k -H "Authorization: Bearer $token" 'https://federate-openshift-user-workload-monitoring.apps.july26.vqqh.p1.openshiftapps.com/federate' --data-urlencode 'match[]=istio_requests_total'
curl -G -s -k -H "Authorization: Bearer $token" 'https://thanos-querier.openshift-monitoring.svc.cluster.local:9091/api/v1/status/config' --data-urlencode 'match[]=istio_requests_total'
```

## gateway header filter

With inspiration from <https://www.alibabacloud.com/help/en/alibaba-cloud-service-mesh/latest/use-envoyfilter-to-add-http-response-headers-in-asm>

debugging...

Verify envoyfilter lua config is applied to only the ingress gateway

```sh
istioctl ps
istioctl pc all istio-ingressgateway-84956f445d-lbd9x.istio-ingress -o json > out.json
```

out.json

```json
...
             {
              "name": "envoy.lua.owaspfilter",
              "typed_config": {
               "@type": "type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua",
               "default_source_code": {
                "inline_string": "function envoy_on_request(request_handle)..."
               }
              }
             }
...
```

```sh
istioctl pc log istio-ingressgateway-84956f445d-lbd9x.istio-ingress --level debug
```
