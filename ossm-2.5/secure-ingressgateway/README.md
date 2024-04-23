# Secure Ingress Gateway

> new: https://www.redhat.com/en/blog/preparing-openshift-service-mesh-3?channel=/en/blog/channel/hybrid-cloud-infrastructure

This example demonstrates:

- An Openshift passthrough route to an ingress gateway that presents a cert-manager certificate using SDS.
- Deploying an ingress gateway using gateway injection
- ClusterWide OSSM 2.5 deployment
- TempoStack
- Service Mesh deployment configuration that uses openshift-monitoing to store metrics for use by Kiali and Grafana

```sh
oc apply -f configmap-cluster-monitoring-config.yaml -n openshift-monitoring
helm upgrade -i namespaces helm/namespaces -n default

oc new-project cert-manager-operator
oc adm new-project openshift-tempo-operator
helm upgrade -i service-mesh-operators -n openshift-operators helm/service-mesh-operators --create-namespace

export istio_system_namespace=istio-system
export istio_ingress_namespace=istio-ingress

helm upgrade -i -n ${istio_ingress_namespace} cert-manager-certs helm/cert-manager 

helm upgrade -i control-plane -n ${istio_system_namespace} helm/control-plane

helm upgrade -i minio-dev helm/minio-dev -n minio-dev --create-namespace

# https://min.io/docs/minio/linux/reference/minio-mc.html#mc-install
oc port-forward deploy/minio-dev 9000 9001 -n minio-dev

mc alias set k8s-minio-dev http://localhost:9000 minioadmin minioadmin
mc admin info k8s-minio-dev
mc mb k8s-minio-dev/tempo 

# watch the bucket
google-chrome http://localhost:9001


helm upgrade -i tempo-system helm/tempo -n tempo-system --create-namespace

helm upgrade -i istio-ingressgateway helm/gateway -n ${istio_ingress_namespace}
 
helm upgrade -i golang-ex-istio helm/golang-ex-istio -n golang-ex --set ingressgateway.host=golang-ex-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain}) --set fullnameOverride=golang-ex
helm upgrade -i golang-ex helm/golang-ex -n golang-ex

helm upgrade -i golang-ex-istio-v2 helm/golang-ex-istio -n golang-ex --set ingressgateway.host=golang-ex-v2-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain}) --set fullnameOverride=golang-ex-v2 
helm upgrade -i golang-ex-v2 helm/golang-ex -n golang-ex

helm upgrade -i golang-ex-istio-common helm/golang-ex-istio-common -n golang-ex 

curl -v http://golang-ex.golang-ex.svc.cluster.local

oc exec -n bookinfo deploy/reviews-v1 -i -t -c reviews -- curl -v -H "x-feature: golang-ex/featurea" http://golang-ex.golang-ex.svc.cluster.local
oc exec mypod -i -t -- ls -t /usr

#TODO seems like grafana will no longer be supported (and istio's grafana dashboards)
helm upgrade -i grafana-operator -n openshift-operators helm/grafana-operator

helm upgrade -i grafana -n ${istio_system_namespace} helm/grafana

helm upgrade -i user-workload-monitoring helm/user-workload-monitoring -n ${istio_system_namespace} \
  --set kiali.tempo.url=https://$(oc get route tempo-minio-dev-query-frontend -n tempo-system -o jsonpath={.spec.host}) \
  --set kiali.grafana.url=https://$(oc get route grafana-instance-route -n ${istio_system_namespace} -o jsonpath={.spec.host})

siege -c 10 -r 100 https://golang-ex-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})
```

## Install nginx-echo-headers Istio Configs

```sh
helm upgrade -i nginx-echo-headers-istio helm/nginx-echo-headers-istio -n nginx-echo-headers --set ingressgateway.host=nginx-echo-headers-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})
```

## Install nginx-echo-headers

```sh
helm upgrade -i nginx-echo-headers helm/nginx-echo-headers -n nginx-echo-headers
```

## Install Bookinfo Istio Configs

```sh
helm upgrade -i bookinfo-istio helm/bookinfo-istio -n bookinfo --set ingressgateway.host=bookinfo-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})
```

## Install Bookinfo

```sh
helm upgrade -i bookinfo helm/bookinfo -n bookinfo
```

## OCP install notes

```sh
aws configure
openshift-install create install-config --dir ./openshift-install
openshift-install create cluster --dir ./openshift-install
```
