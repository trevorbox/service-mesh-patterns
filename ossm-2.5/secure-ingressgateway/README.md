# Secure Ingress Gateway

This example demonstrates:

- An Openshift passthrough route to an ingress gateway that presents a cert-manager certificate using SDS.
- Deploying an ingress gateway using gateway injection
- A possible production Service Mesh deployment configuration that uses openshift-monitoing to store metrics for use by Kiali and Grafana
- Deploying OPA Gatekeeper to require sidecar annotation in pods in mesh member namespaces
- Deploying an EnvoyFilter to enforce OWASP response header manipulation requirements
- Deploying a [WASM Plugin](https://github.com/corazawaf/coraza-proxy-wasm/tree/main/example/istio#at-ingress-gateway-for-all-incoming-traffic) to enforce OWASP CRS <https://github.com/coreruleset/coreruleset> for all traffic entering through the ingress gateway

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

This application allows us to test the EnvoyFilter response header manipulation on the ingress gateway. The headers returned by the application may be changed in the deployment's response-headers configmap.

```sh
helm upgrade --create-namespace -i golang-ex helm/golang-ex -n golang-ex
```

## Test golang-ex

```sh
curl -ik https://api-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})/golang-ex
```

## user monitoring

<https://docs.openshift.com/container-platform/4.13/service_mesh/v2x/ossm-observability.html#ossm-integrating-with-user-workload-monitoring_observability>

This solution includes custom kiali configuration to use openshift-monitoring prometheus. Grafana also uses openshift prometheus.

```sh
oc apply -f configmap-cluster-monitoring-config.yaml -n openshift-monitoring
# if using rosa
IS_ROSA=true
helm upgrade --create-namespace -i control-plane -n ${istio_system_namespace} helm/control-plane -f helm/control-plane/values-user-monitoring.yaml --set isRosa=${IS_ROSA}
helm upgrade -i user-workload-monitoring helm/user-workload-monitoring -n ${istio_system_namespace} \
  --set kiali.jaeger.url=https://$(oc get route jaeger -n ${istio_system_namespace} -o jsonpath={.spec.host}) \
  --set kiali.grafana.url=https://$(oc get route grafana-instance-route -n ${istio_system_namespace} -o jsonpath={.spec.host})
```

grafana...

```sh
helm upgrade -i grafana-operator -n openshift-operators helm/grafana-operator
helm upgrade -i grafana -n ${istio_system_namespace} helm/grafana
```

testing prometheus auth notes...

```sh
export token=
curl -G -s -k -H "Authorization: Bearer $token" 'https://federate-openshift-user-workload-monitoring.apps.july26.vqqh.p1.openshiftapps.com/federate' --data-urlencode 'match[]=istio_requests_total'
curl -G -s -k -H "Authorization: Bearer $token" 'https://thanos-querier.openshift-monitoring.svc.cluster.local:9091/api/v1/status/config' --data-urlencode 'match[]=istio_requests_total'
```

```sh
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.16/samples/addons/grafana.yaml
```

## gateway header filter

With inspiration from <https://www.alibabacloud.com/help/en/alibaba-cloud-service-mesh/latest/use-envoyfilter-to-add-http-response-headers-in-asm>

The [owasp-gateway-filter](./helm/injected-gateway/templates/envoyfilter-owasp-gateway-filter.yaml) was previously deployed from the injected-gateway chart...

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

```sh
siege -c 10 -r 100 https://api-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})/golang-ex
```

## Test [Coraza WASM plugin](https://github.com/corazawaf/coraza-proxy-wasm/tree/main/example/istio#at-ingress-gateway-for-all-incoming-traffic)

```sh
curl -ik https://api-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})/nginx-echo-headers?arg=\<script\>alert\(0\)\</script\>
```

log output from ingress gateway pod...

```txt
2024-03-14T00:01:33.101867Z critical envoy wasm wasm log istio-ingress.coraza-ingressgateway: [client "10.217.0.1"] Coraza: Warning. XSS Attack Detected via libinjection [file "@owasp_crs/REQUEST-941-APPLICATION-ATTACK-XSS.conf"] [line "7663"] [id "941100"] [rev ""] [msg "XSS Attack Detected via libinjection"] [data "Matched Data: XSS data found within ARGS_GET:arg: <script>alert(0)</script>"] [severity "critical"] [ver "OWASP_CRS/4.0.0-rc2"] [maturity "0"] [accuracy "0"] [tag "application-multi"] [tag "language-multi"] [tag "platform-multi"] [tag "attack-xss"] [tag "paranoia-level/1"] [tag "OWASP_CRS"] [tag "capec/1000/152/242"] [hostname "10.217.1.29"] [uri "/nginx-echo-headers?arg=<script>alert(0)</script>"] [unique_id "AEvaZrZNqmkUTKzKVTy"]
2024-03-14T00:01:33.102310Z critical envoy wasm wasm log istio-ingress.coraza-ingressgateway: [client "10.217.0.1"] Coraza: Warning. XSS Filter - Category 1: Script Tag Vector [file "@owasp_crs/REQUEST-941-APPLICATION-ATTACK-XSS.conf"] [line "7689"] [id "941110"] [rev ""] [msg "XSS Filter - Category 1: Script Tag Vector"] [data "Matched Data: <script> found within ARGS_GET:arg: <script>alert(0)</script>"] [severity "critical"] [ver "OWASP_CRS/4.0.0-rc2"] [maturity "0"] [accuracy "0"] [tag "application-multi"] [tag "language-multi"] [tag "platform-multi"] [tag "attack-xss"] [tag "paranoia-level/1"] [tag "OWASP_CRS"] [tag "capec/1000/152/242"] [hostname "10.217.1.29"] [uri "/nginx-echo-headers?arg=<script>alert(0)</script>"] [unique_id "AEvaZrZNqmkUTKzKVTy"]
2024-03-14T00:01:33.104775Z critical envoy wasm wasm log istio-ingress.coraza-ingressgateway: [client "10.217.0.1"] Coraza: Warning. NoScript XSS InjectionChecker: HTML Injection [file "@owasp_crs/REQUEST-941-APPLICATION-ATTACK-XSS.conf"] [line "7778"] [id "941160"] [rev ""] [msg "NoScript XSS InjectionChecker: HTML Injection"] [data "Matched Data: <script found within ARGS_GET:arg: <script>alert(0)</script>"] [severity "critical"] [ver "OWASP_CRS/4.0.0-rc2"] [maturity "0"] [accuracy "0"] [tag "application-multi"] [tag "language-multi"] [tag "platform-multi"] [tag "attack-xss"] [tag "paranoia-level/1"] [tag "OWASP_CRS"] [tag "capec/1000/152/242"] [hostname "10.217.1.29"] [uri "/nginx-echo-headers?arg=<script>alert(0)</script>"] [unique_id "AEvaZrZNqmkUTKzKVTy"]
2024-03-14T00:01:33.108100Z critical envoy wasm wasm log istio-ingress.coraza-ingressgateway: [client "10.217.0.1"] Coraza: Warning. Javascript method detected [file "@owasp_crs/REQUEST-941-APPLICATION-ATTACK-XSS.conf"] [line "8272"] [id "941390"] [rev ""] [msg "Javascript method detected"] [data "Matched Data: alert( found within ARGS_GET:arg: <script>alert(0)</script>"] [severity "critical"] [ver "OWASP_CRS/4.0.0-rc2"] [maturity "0"] [accuracy "0"] [tag "application-multi"] [tag "language-multi"] [tag "attack-xss"] [tag "paranoia-level/1"] [tag "OWASP_CRS"] [tag "capec/1000/152/242"] [hostname "10.217.1.29"] [uri "/nginx-echo-headers?arg=<script>alert(0)</script>"] [unique_id "AEvaZrZNqmkUTKzKVTy"]
2024-03-14T00:01:33.110860Z critical envoy wasm wasm log istio-ingress.coraza-ingressgateway: [client "10.217.0.1"] Coraza: Access denied (phase 1). Inbound Anomaly Score Exceeded in phase 1 (Total Score: 20) [file "@owasp_crs/REQUEST-949-BLOCKING-EVALUATION.conf"] [line "11347"] [id "949111"] [rev ""] [msg "Inbound Anomaly Score Exceeded in phase 1 (Total Score: 20)"] [data ""] [severity "emergency"] [ver "OWASP_CRS/4.0.0-rc2"] [maturity "0"] [accuracy "0"] [tag "anomaly-evaluation"] [hostname "10.217.1.29"] [uri "/nginx-echo-headers?arg=<script>alert(0)</script>"] [unique_id "AEvaZrZNqmkUTKzKVTy"]
[2024-03-14T00:01:33.092Z] "GET /nginx-echo-headers?arg=<script>alert(0)</script> HTTP/2" 403 - - "-" 0 0 19 - "10.217.0.1" "curl/8.0.1" "066505bf-0b0d-9ac4-a0f1-348ada628034" "api-istio-ingress.apps-crc.testing" "-" outbound|8080||nginx-echo-headers.nginx-echo-headers.svc.cluster.local - 10.217.1.29:8443 10.217.0.1:51776 api-istio-ingress.apps-crc.testing -
```

## gatekeeper policies

```sh
helm upgrade -i gatekeeper-operator helm/gatekeeper-operator -n openshift-operators
helm upgrade -i gatekeeper helm/gatekeeper -n openshift-gatekeeper-system --create-namespace
helm upgrade -i gatekeeper-constrainttemplates helm/gatekeeper-constrainttemplates -n openshift-gatekeeper-system
helm upgrade -i gatekeeper-constraints helm/gatekeeper-constraints -n openshift-gatekeeper-system
```
