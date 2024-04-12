```sh
helm upgrade -i namespaces helm/namespaces

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

# problem with the route
oc port-forward deploy/tempo-minio-dev-query-frontend 16686 -n tempo-system
google-chrome http://localhost:16686

# watch the bucket
google-chrome http://localhost:9001

helm upgrade -i tempo-system helm/tempo -n tempo-system

helm upgrade -i istio-ingressgateway helm/gateway -n ${istio_ingress_namespace}
 
helm upgrade -i golang-ex-istio helm/golang-ex-istio -n golang-ex --set ingressgateway.host=golang-ex-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})
helm upgrade -i golang-ex helm/golang-ex -n golang-ex


helm upgrade -i grafana-operator -n openshift-operators helm/grafana-operator

helm upgrade -i grafana -n ${istio_system_namespace} helm/grafana

oc apply -f configmap-cluster-monitoring-config.yaml -n openshift-monitoring

helm upgrade -i user-workload-monitoring helm/user-workload-monitoring -n ${istio_system_namespace} \
  --set kiali.tempo.url=https://$(oc get route tempo-minio-dev-query-frontend -n tempo-system -o jsonpath={.spec.host}) \
  --set kiali.grafana.url=https://$(oc get route grafana-instance-route -n ${istio_system_namespace} -o jsonpath={.spec.host})

NOTE: had to manually restart tempo pods for it to start working

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


```sh
aws configure
openshift-install create install-config --dir ./openshift-install
openshift-install create cluster --dir ./openshift-install
```
