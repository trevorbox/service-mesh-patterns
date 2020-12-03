# Deploy RHACM resources to HUB

```sh
helm upgrade -i --create-namespace servicemeshoperators helm/servicemeshoperators -n rhacm-global-operators
helm upgrade -i --create-namespace control-plane helm/control-plane-oauth2 -n istio-system
helm upgrade -i --create-namespace bookinfo-istio helm/bookinfo-istio -n bookinfo
helm upgrade -i --create-namespace bookinfo helm/bookinfo -n bookinfo
```
