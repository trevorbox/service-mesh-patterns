# TLS origination

## Install the control plane

```sh
oc new-project istio-system

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
oc rsh -n bookinfo -c ratings deployment/ratings-v1 curl -v -I http://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host})

oc rsh -n istio-system -c istio-proxy deployment/istio-egressgateway curl -v https://$(oc get route nginx -n mesh-external -o jsonpath={.spec.host}) --cacert /etc/configmaps/ca.crt
```
