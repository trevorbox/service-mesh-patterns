# TLS origination

## Create root ca configmap

```sh
oc new-project istio-system

oc get secrets -n openshift-ingress-operator router-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ca.crt
oc -n istio-system create configmap ocp-ca-bundle --from-file=/tmp/ca.crt
```

## Install the control plane

```sh
helm upgrade -i control-plane -n istio-system control-plane
```

> TODO add steps for installing bookinfo

```sh
cd ..
./install-basic-gateway-configuration.sh
```

> TODO figure out how to add the configmap volumemount - doing that manually right now

## Install the configurations

```sh
oc new-project mesh-external

oc new-app centos/nginx-112-centos7~https://github.com/sclorg/nginx-ex -n mesh-external

helm upgrade -i egress -n bookinfo egressgateway-tls-origination
```

```sh
oc rsh -n bookinfo -c ratings deployment/ratings-v1 curl -v http://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host})

oc rsh -n istio-system -c istio-proxy deployment/istio-egressgateway curl -v https://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host}) --cacert /etc/configmaps/trusted-ca-bundle/ca-bundle.crt

oc rsh -n istio-system -c istio-proxy deployment/istio-egressgateway curl -v https://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host}) --cacert /etc/configmaps/ocp-ca-bundle/ca.crt
```