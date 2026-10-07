# CoreDNS

## What is CoreDNS?

**CoreDNS** is a small, fast DNS server written in Go and built entirely out of **plugins** (each
line of its config file - the `Corefile` - enables one plugin). It is a CNCF graduated project and
has been the **default cluster DNS of Kubernetes since v1.13**, replacing the older `kube-dns`
(dnsmasq + sidecars). For backwards compatibility it still runs behind a Service called
**`kube-dns`** in the `kube-system` namespace.

In my minikube cluster it runs as a **Deployment `coredns`** in `kube-system`, exposed by the
**Service `kube-dns`** (ClusterIP `10.96.0.10`, ports 53/UDP, 53/TCP, 9153/TCP for metrics).

## Why Kubernetes uses CoreDNS

- **Service discovery by name** - Pods and Services get new IPs all the time; apps need stable names.
- **Kubernetes-native** - the `kubernetes` plugin watches the API server directly, so records are
  updated within seconds when Services or Pods change (no zone files to edit).
- **Single binary, plugin based** - caching, forwarding, metrics, health checks, rewriting, logging
  are all just plugins; easy to extend.
- **Lighter and more secure than kube-dns** - one container instead of three, written in a memory
  safe language.
- **Configured with a ConfigMap** (`coredns` in `kube-system`), so it can be tuned without
  rebuilding anything (stub domains, custom hosts, upstream resolvers).

## How Service discovery works

1. You create a Service. The API server stores it and allocates a ClusterIP.
2. The EndpointSlice controller fills in the Service's EndpointSlices with the IPs of the *ready*
   Pods matching its selector.
3. CoreDNS's `kubernetes` plugin keeps a watch on Services + EndpointSlices and builds DNS records
   in memory:
   - `<svc>.<ns>.svc.cluster.local` -> A record = ClusterIP
   - headless Service -> one A record per ready Pod
   - ExternalName -> CNAME
   - named ports -> SRV records
4. kubelet writes `/etc/resolv.conf` into every Pod (`dnsPolicy: ClusterFirst`, the default) with
   `nameserver <kube-dns ClusterIP>` and a namespace-based `search` list.
5. Pods simply call `http://my-service` and the name resolves.

## How DNS queries are resolved

```
Pod (ns: s11-services) runs:  nslookup web-service-clusterip
  |
  | /etc/resolv.conf:  nameserver 10.96.0.10
  |                    search s11-services.svc.cluster.local svc.cluster.local cluster.local
  |                    options ndots:5
  |  -> name has < 5 dots, so try search suffixes first:
  |     web-service-clusterip.s11-services.svc.cluster.local ?
  v
kube-dns Service 10.96.0.10:53  --(kube-proxy DNAT)-->  a coredns Pod
  |
  |  Corefile server block ".:53" - plugins run in order:
  |    errors / health / ready
  |    kubernetes cluster.local in-addr.arpa ip6.arpa  -> authoritative for cluster.local:
  |         found Service -> answer ClusterIP  (NXDOMAIN if it does not exist)
  |    hosts { 192.168.49.1 host.minikube.internal }  (minikube addition)
  |    prometheus :9153                               -> metrics
  |    forward . /etc/resolv.conf                     -> anything NOT in cluster.local
  |                                                      (e.g. example.com) goes upstream
  |    cache 30                                       -> answers cached for 30s
  |    loop / reload / loadbalance
  v
answer: web-service-clusterip.s11-services.svc.cluster.local -> 10.x.x.x
```

## CoreDNS configuration

The real Corefile from my cluster is captured below (`kubectl get configmap coredns -n kube-system -o yaml`).
Key plugins:

| Plugin | What it does |
|---|---|
| `errors` | log errors to stdout |
| `health` / `ready` | liveness (`:8080/health`) and readiness (`:8181/ready`) endpoints used by the Pod probes |
| `kubernetes cluster.local in-addr.arpa ip6.arpa` | serve cluster records + reverse lookups; `pods insecure` enables `a-b-c-d.<ns>.pod.cluster.local` records; `fallthrough` passes misses on to the next plugin |
| `hosts` | static host entries (minikube adds `host.minikube.internal`) |
| `prometheus :9153` | metrics endpoint |
| `forward . /etc/resolv.conf` | send non-cluster names to the node's upstream resolvers |
| `cache 30` | cache answers for 30 seconds |
| `loop` | detect and stop forwarding loops |
| `reload` | re-read the Corefile automatically when the ConfigMap changes |
| `loadbalance` | round-robin the order of A records in answers |

## How to troubleshoot DNS issues

Checklist I used (all real output below):

1. **Is CoreDNS running?** `kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide`
2. **Does the kube-dns Service have endpoints?** `kubectl get svc,endpointslices -n kube-system -l k8s-app=kube-dns`
3. **What does the Pod use as DNS?** `kubectl exec <pod> -- cat /etc/resolv.conf`
4. **Can the Pod resolve the API server?** `nslookup kubernetes.default`
5. **Can it resolve my Service (short + FQDN)?** `nslookup <svc>` / `nslookup <svc>.<ns>.svc.cluster.local`
6. **Can it resolve external names?** `nslookup example.com` (tests the `forward` plugin / upstream)
7. **Wrong name / wrong namespace?** NXDOMAIN means the record does not exist - check spelling and namespace.
8. **Name resolves but the connection fails?** That is *not* a DNS problem - check the Service's
   endpoints (`kubectl get endpointslices -l kubernetes.io/service-name=<svc>`); an empty list means
   the selector matches no ready Pods (demo below with `empty-endpoints.yaml`).
9. **CoreDNS logs:** `kubectl logs -n kube-system -l k8s-app=kube-dns` (add the `log` plugin to the
   Corefile temporarily to log every query - not done here because the cluster is shared).
10. **Config:** `kubectl get configmap coredns -n kube-system -o yaml` - look for typos in `forward`,
    missing `kubernetes` block, etc.

---

## Hands-on (real output)

All commands were run from the `Kubernetes-Networking-Services/` folder. The test client is
[`../dns-test/curl-test-pod.yaml`](../dns-test/curl-test-pod.yaml) running in namespace `s11-services`.
