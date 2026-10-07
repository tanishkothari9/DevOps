# DNS Issues

Every Service gets a DNS name from **CoreDNS**:

```text
<service>.<namespace>.svc.cluster.local
```

Inside a Pod, `/etc/resolv.conf` points at the `kube-dns` Service and adds **search domains** for the
Pod's own namespace, so the short name `orders-api` only works **from the same namespace**.

Scenario: a `frontend` Pod in namespace `s14-dns` calls the `orders-api` backend, which lives in a
**different** namespace, `s14-dns-backend`, using the short name `http://orders-api`.

| File | Description |
|---|---|
| `backend.yaml` | namespace `s14-dns-backend` + `orders-api` Deployment (nginx) + Service |
| `broken-frontend.yaml` | namespace `s14-dns` + `frontend` Pod calling `BACKEND_URL=http://orders-api` every 5s |
| `fixed-frontend.yaml` | same Pod with `BACKEND_URL=http://orders-api.s14-dns-backend.svc.cluster.local` |
| `dns-test-pod.yaml` | busybox Pod for `nslookup` |

## 1. Identify the problem

```bash
kubectl apply -f backend.yaml -f broken-frontend.yaml -f dns-test-pod.yaml
```
![apply](screenshots/01-apply-backend-and-broken-frontend.png)

All Pods are Running, but the frontend logs show every call failing:
```bash
kubectl get pods -n s14-dns; kubectl get pods -n s14-dns-backend; kubectl logs frontend -n s14-dns --tail=6
```
```text
NAME       READY   STATUS    RESTARTS   AGE
dns-test   1/1     Running   0          21m
frontend   1/1     Running   0          21m
NAME                          READY   STATUS    RESTARTS   AGE
orders-api-68fdc85f77-m64f9   1/1     Running   0          21m

18:56:10 calling http://orders-api
FAILED
wget: bad address 'orders-api'
```
![logs](screenshots/02-get-pods-logs.png)

`bad address` = the hostname could not be resolved. It's a DNS problem, not a network problem.

## 2. Investigate

Look the name up from a Pod in the same namespace and check the resolver config:
```bash
kubectl exec dns-test -n s14-dns -- nslookup orders-api
kubectl exec dns-test -n s14-dns -- cat /etc/resolv.conf
```
```text
Server:		10.96.0.10
** server can't find orders-api.s14-dns.svc.cluster.local: NXDOMAIN
** server can't find orders-api.svc.cluster.local: NXDOMAIN
** server can't find orders-api.cluster.local: NXDOMAIN
command terminated with exit code 1

search s14-dns.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```
![nslookup short](screenshots/03-nslookup-short-name.png)

The resolver expanded `orders-api` with the search domains, and the first try was
`orders-api.s14-dns.svc.cluster.local` - i.e. it looked in the **frontend's** namespace. NXDOMAIN
everywhere. So where is the Service?
```bash
kubectl get svc -A | grep -E "NAMESPACE|orders-api"
```
```text
NAMESPACE           NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
s14-dns-backend     orders-api    ClusterIP   10.98.29.153     <none>        80/TCP    21m
```
![find svc](screenshots/04-find-service.png)

Resolve the fully-qualified name:
```bash
kubectl exec dns-test -n s14-dns -- nslookup orders-api.s14-dns-backend.svc.cluster.local
kubectl exec dns-test -n s14-dns -- nslookup orders-api.s14-dns-backend
```
```text
Name:	orders-api.s14-dns-backend.svc.cluster.local
Address: 10.98.29.153

** server can't find orders-api.s14-dns-backend: NXDOMAIN
```
![fqdn](screenshots/05-nslookup-fqdn.png)

The FQDN resolves to the Service ClusterIP `10.98.29.153`. (busybox's `nslookup` only applies the search
list to names *without* a dot, so `orders-api.s14-dns-backend` is looked up literally - another reason to
use the full name when testing.)

Is CoreDNS itself healthy?
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get svc kube-dns -n kube-system
kubectl get endpointslices -n kube-system -l kubernetes.io/service-name=kube-dns
```
```text
NAME                       READY   STATUS    RESTARTS   AGE
coredns-559f6c778d-dfnhj   1/1     Running   1          143m
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   143m
NAME             ADDRESSTYPE   PORTS        ENDPOINTS    AGE
kube-dns-pzq8z   IPv4          53,53,9153   10.244.0.2   143m
```
![coredns](screenshots/06-coredns-health.png)

> **A second, real DNS failure I hit during this exercise:** the first time I ran the FQDN lookup, the
> shared minikube node was overloaded and the CoreDNS Pod was `0/1 Running` (its readiness probe was
> timing out). With no ready CoreDNS endpoint, *every* lookup failed - even the correct FQDN - with
> `nslookup: write to '10.96.0.10': Connection refused` / `connection timed out; no servers could be reached`.
> The check above (`kubectl get pods -n kube-system -l k8s-app=kube-dns` and the `kube-dns` endpoints)
> is exactly how you tell "my name is wrong" (NXDOMAIN) apart from "cluster DNS is down"
> (connection refused / timeout). Once CoreDNS was `1/1` again, the FQDN resolved as shown.

## 3. Root cause

The frontend uses the short name `orders-api`, which is expanded with the frontend's own namespace
(`s14-dns`). The Service lives in `s14-dns-backend`, so the lookup returns NXDOMAIN and `wget` reports
`bad address`. CoreDNS itself is fine.

## 4. Fix

Use the cross-namespace name `orders-api.s14-dns-backend.svc.cluster.local` (or at least
`orders-api.s14-dns-backend` with a glibc/musl resolver):
```bash
kubectl delete pod frontend -n s14-dns && kubectl apply -f fixed-frontend.yaml && kubectl wait --for=condition=Ready pod/frontend -n s14-dns --timeout=240s
```
![fix](screenshots/07-fix.png)

## 5. Verify

```bash
kubectl get pod frontend -n s14-dns -o jsonpath="BACKEND_URL={.spec.containers[0].env[0].value}"; kubectl logs frontend -n s14-dns --tail=6
```
```text
BACKEND_URL=http://orders-api.s14-dns-backend.svc.cluster.local
19:19:17 calling http://orders-api.s14-dns-backend.svc.cluster.local
OK
19:19:22 calling http://orders-api.s14-dns-backend.svc.cluster.local
OK
```
![verify](screenshots/08-verify.png)

## Before / after

| | Before | After |
|---|---|---|
| `BACKEND_URL` | `http://orders-api` | `http://orders-api.s14-dns-backend.svc.cluster.local` |
| frontend log | `wget: bad address 'orders-api'` / `FAILED` | `OK` every 5s |

**DNS checklist:** `nslookup <name>` from a Pod -> NXDOMAIN? check the namespace (`kubectl get svc -A`)
and use the FQDN -> timeout / connection refused? check CoreDNS Pods and `kube-dns` endpoints ->
check `/etc/resolv.conf` in the Pod.
