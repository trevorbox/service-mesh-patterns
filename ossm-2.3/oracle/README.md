# https://github.com/oracle/docker-images/tree/main/OracleDatabase/SingleInstance/samples/kubernetes
# https://container-registry.oracle.com/ords/f?p=113:1:103217599269754:::1:P1_BUSINESS_AREA:3&cs=3dPc9rp3GGjWwllz-QNYPvkYrSAJbJ9Fy5C1Y08gR8ZEsWCOaw5ce1uQdXfZMr-5kZTvyD_opIiI7tcOz8SOgQQ

```sh
kubectl run --namespace example-namespace \
             -i --tty temporary \
             --image=container-registry.oracle.com/database/sqlcl:latest
```