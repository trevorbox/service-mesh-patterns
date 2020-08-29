# TLS origination

## Install the control plane

```sh
oc new-project istio-system

helm upgrade -i control-plane -n istio-system
```

> TODO add steps for installing bookinfo

## Install the configurations

```sh
oc new-app centos/nginx-112-centos7~https://github.com/sclorg/nginx-ex -n mesh-external

helm upgrade -i egress -n bookinfo egressgateway-tls-origination
```
