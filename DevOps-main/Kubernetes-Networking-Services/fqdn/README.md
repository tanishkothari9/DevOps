# FQDN in Kubernetes

## What is an FQDN?

A **Fully Qualified Domain Name** is the *complete* DNS name of a host - every label from the host
up to the root of the DNS tree - so it can be resolved unambiguously from anywhere.

```
www.example.com.          <- the trailing "." is the DNS root
 |     |      |
host  domain  TLD
```

A short name such as `web` is **not** fully qualified: the resolver has to guess the rest by trying
the domains listed in the `search` line of `/etc/resolv.conf`. An FQDN needs no guessing.

## Kubernetes Service DNS

Every Service gets a DNS record served by **CoreDNS** (the `kube-dns` Service in `kube-system`). Pods
are configured by the kubelet to use CoreDNS as their nameserver, so any Pod can reach any Service by
name instead of by IP.

| Service type | What the DNS name resolves to |
|---|---|
| ClusterIP / NodePort / LoadBalancer | an **A record** -> the Service's single ClusterIP |
| Headless (`clusterIP: None`) | **one A record per ready Pod** (the Pod IPs) + per-Pod names for StatefulSets |
| ExternalName | a **CNAME** -> the external host name (e.g. `example.com`) |

Named ports also get **SRV records**: `_http._tcp.web-service-clusterip.s11-services.svc.cluster.local`.

## Kubernetes DNS naming convention

```
<service-name>.<namespace>.svc.<cluster-domain>
web-service-clusterip.s11-services.svc.cluster.local
```

| Part | Meaning | Value in my cluster |
|---|---|---|
| `<service-name>` | `metadata.name` of the Service | `web-service-clusterip` |
| `<namespace>` | namespace of the Service | `s11-services` |
| `svc` | fixed - "this is a Service record" | `svc` |
| `<cluster-domain>` | set in kubelet / CoreDNS config | `cluster.local` (default) |

Other record forms:

| Object | FQDN pattern |
|---|---|
| StatefulSet Pod behind a headless Service | `<pod-name>.<headless-svc>.<ns>.svc.cluster.local` -> `web-stateful-0.web-service-headless.s11-services.svc.cluster.local` |
| Any Pod by IP (dashed) | `<a-b-c-d>.<ns>.pod.cluster.local` -> `10-244-0-12.s11-services.pod.cluster.local` |
| The API server | `kubernetes.default.svc.cluster.local` |

## Namespace-based DNS

Every Pod's `/etc/resolv.conf` contains a **search list** built from its own namespace:

```
search s11-services.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

So, from a Pod in namespace `s11-services`:

| You type | Resolver tries | Works? |
|---|---|---|
| `web-service-clusterip` | `web-service-clusterip.s11-services.svc.cluster.local` | yes - same namespace |
| `web-service-clusterip.s11-services` | `web-service-clusterip.s11-services.svc.cluster.local` (2nd search entry) | yes - from any namespace |
| `web-service-clusterip.s11-services.svc.cluster.local` | used as is | yes - from anywhere |

From a Pod in a **different** namespace (`s11-other`), the short name fails (it expands to
`web-service-clusterip.s11-other.svc.cluster.local`, which does not exist) - you must add at least
`.<namespace>`. This is exactly what the demo below shows.

`ndots:5` means: a name with fewer than 5 dots is first tried with every search suffix. Writing the
full FQDN *with a trailing dot* (`...cluster.local.`) skips the search list and saves DNS lookups.

## Pod-to-Service communication

1. App calls `http://web-service-clusterip:8080`.
2. The Pod's resolver appends the search suffixes and asks CoreDNS (`10.96.0.10`).
3. CoreDNS (`kubernetes` plugin, which watches Services/EndpointSlices via the API server) answers
   with the Service's ClusterIP.
4. The Pod opens a TCP connection to `ClusterIP:8080`.
5. kube-proxy's iptables rules on the node DNAT it to one of the ready Pod IPs on `targetPort` 80.

## Examples of Kubernetes FQDNs

| FQDN | Resolves to |
|---|---|
| `kubernetes.default.svc.cluster.local` | API server ClusterIP (10.96.0.1) |
| `kube-dns.kube-system.svc.cluster.local` | CoreDNS ClusterIP (10.96.0.10) |
| `web-service-clusterip.s11-services.svc.cluster.local` | ClusterIP of the 01-clusterip demo |
| `web-service-headless.s11-services.svc.cluster.local` | 3 Pod IPs of the StatefulSet |
| `web-stateful-1.web-service-headless.s11-services.svc.cluster.local` | the IP of Pod `web-stateful-1` only |
| `external-database-service.s11-services.svc.cluster.local` | CNAME `example.com` |
| `ingress-nginx-controller.ingress-nginx.svc.cluster.local` | the minikube ingress controller Service |

---

## Hands-on proof (real output)

Run from the `Kubernetes-Networking-Services/` folder. Client Pods: `curl-test-pod` in
`s11-services`, and a second copy in namespace `s11-other`
(YAML: [`../dns-test/curl-test-pod.yaml`](../dns-test/curl-test-pod.yaml)).
