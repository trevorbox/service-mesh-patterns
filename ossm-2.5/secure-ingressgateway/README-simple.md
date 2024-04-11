```sh
oc adm new-project openshift-operators-redhat
oc adm new-project openshift-distributed-tracing
oc new-project cert-manager-operator
helm upgrade -i service-mesh-operators -n openshift-operators helm/service-mesh-operators --create-namespace

export istio_system_namespace=istio-system
export istio_ingress_namespace=istio-ingress

helm upgrade -i --create-namespace -n ${istio_ingress_namespace} cert-manager-certs helm/cert-manager --set ingressgateway.cert.commonName=api-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})

helm upgrade --create-namespace -i control-plane -n ${istio_system_namespace} helm/control-plane -f helm/control-plane/values-user-monitoring.yaml



helm upgrade -i istio-ingressgateway helm/gateway -n ${istio_ingress_namespace}
helm upgrade --create-namespace -i golang-ex-istio helm/golang-ex-istio -n golang-ex --set ingressgateway.host=$(oc get route api -n ${istio_ingress_namespace} -o jsonpath={'.spec.host'})
helm upgrade --create-namespace -i golang-ex helm/golang-ex -n golang-ex




helm upgrade -i grafana-operator -n openshift-operators helm/grafana-operator
helm upgrade -i grafana -n ${istio_system_namespace} helm/grafana

helm upgrade -i user-workload-monitoring helm/user-workload-monitoring -n ${istio_system_namespace} \
  --set kiali.jaeger.url=https:// \
  --set kiali.grafana.url=https://$(oc get route grafana-instance-route -n ${istio_system_namespace} -o jsonpath={.spec.host})

helm upgrade -i minio-dev helm/minio-dev -n minio-dev --create-namespace

# https://min.io/docs/minio/linux/reference/minio-mc.html#mc-install
mc alias set k8s-minio-dev http://minio-minio-dev.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain}) minioadmin minioadmin
mc admin info k8s-minio-dev
mc mb k8s-minio-dev/tempo 

helm upgrade -i tempo-operator helm/tempo-operator -n openshift-tempo-operator --create-namespace

helm upgrade -i tempo-dev helm/tempo -n tempo-dev --create-namespace

NOTE: had to manually restart tempo pods for it to start working






siege -c 10 -r 100 https://api-${istio_ingress_namespace}.$(oc get ingress.config.openshift.io cluster -o jsonpath={.spec.domain})/golang-ex
```


#TODO 

```
// Include namespaces whose labels match any of the specified selectors.
	// +optional
	MemberSelectors []metav1.LabelSelector `json:"memberSelectors,omitempty"`
```