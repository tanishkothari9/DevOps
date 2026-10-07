# Ingress vs Ingress Controller

## What is an Ingress?

An **Ingress** is a Kubernetes API object (`kind: Ingress`, group `networking.k8s.io/v1`) that
holds **HTTP/HTTPS routing rules**: "requests for host `X` and path `Y` go to Service `Z` on port `P`".
It can also hold TLS settings (which Secret holds the certificate for which host).

On its own an Ingress is **only configuration stored in etcd**. Nothing listens on a port and no
traffic moves just because you ran `kubectl apply -f ingress.yaml`.

```yaml
# 03-ingress/ingress.yaml (excerpt)
spec:
  ingressClassName: nginx          # which controller should implement me
  rules:
    - host: yatri.local
      http:
        paths:
          - path: /api   -> yatri-backend-service:80
          - path: /      -> yatri-frontend-service:80
    - host: api.yatri.local
      http:
        paths:
          - path: /      -> yatri-backend-service:80
```

## What is an Ingress Controller?

An **Ingress Controller** is a **running application** (Pods + a Service) that:

1. **watches** the API server for Ingress objects (and the Services/EndpointSlices they point to),
2. **translates** them into the configuration of a real reverse proxy / load balancer
   (for ingress-nginx this is an `nginx.conf` that it reloads automatically),
3. **receives** the external traffic and proxies it straight to the Pod IPs behind the Service.

Kubernetes ships **no** Ingress Controller by default - you install one. On minikube it is the
`ingress` addon, which deploys **ingress-nginx** into the `ingress-nginx` namespace. In my cluster:

- Deployment `ingress-nginx-controller` (the nginx proxy + controller logic)
- Service `ingress-nginx-controller` (the entry point, NodePort on minikube, `LoadBalancer` in the cloud)
- IngressClass `nginx` (the name that Ingress objects reference via `ingressClassName: nginx`)

The real output is in the main [README](../README.md#the-ingress-controller-in-my-cluster) (`kubectl get pods,svc -n ingress-nginx`, `kubectl get ingressclass`).

## Difference between them

| | Ingress | Ingress Controller |
|---|---|---|
| What it is | A Kubernetes **resource** (YAML / API object) | A **program** running in Pods |
| Role | Declares *what* should happen (rules) | Makes it happen (proxies the traffic) |
| Created by | `kubectl apply -f ingress.yaml` (app teams) | Installed once per cluster (platform team / `minikube addons enable ingress` / Helm) |
| Lives in | etcd, via the API server | Pods in its own namespace (`ingress-nginx`) |
| Count | Many - one or more per app/team | Usually one (or a few) per cluster |
| Handles traffic? | No | Yes - it is the reverse proxy |
| Examples | `yatri-ingress` in this repo | ingress-nginx, Traefik, HAProxy, Contour, Kong, AWS Load Balancer Controller, GKE Ingress |

Analogy: the **Ingress** is the list of instructions taped to the reception desk ("deliveries for
the API team go to floor 3"); the **Ingress Controller** is the receptionist who actually reads the
list and walks every visitor to the right floor. Instructions without a receptionist do nothing; a
receptionist without instructions does not know where to send anybody (ingress-nginx answers `404`).

## Why both are required

- **Ingress without a controller** - the object is accepted by the API server, but its `ADDRESS`
  stays empty and no request is ever routed. This is the most common "my Ingress does nothing"
  mistake on a fresh cluster.
- **Controller without an Ingress** - the proxy runs and accepts connections, but has no rules, so
  every request gets the controller's default backend (`404 Not Found`). This is also visible in my
  demo: a request with an unknown `Host` header returns ingress-nginx's 404 page.
- Splitting them keeps **routing rules portable**: the same Ingress YAML works with any controller
  that implements the `nginx`/other IngressClass, and app teams can manage their own rules without
  touching the shared proxy.

## Examples

**1. Path-based routing (one host, many services)**
```
http://yatri.local/       -> yatri-frontend-service
http://yatri.local/api    -> yatri-backend-service
```

**2. Host-based routing (many hosts, one IP)**
```
http://yatri.local/       -> yatri-frontend-service
http://api.yatri.local/   -> yatri-backend-service
```

**3. TLS termination** (from the reference repo's `ingress-tls.yaml`)
```yaml
spec:
  tls:
    - hosts: [portal.campus.local]
      secretName: campus-tls-cert   # kubernetes.io/tls Secret with tls.crt / tls.key
```
The controller terminates HTTPS with that certificate and forwards plain HTTP to the Service.

**4. Why not just use `type: LoadBalancer` for everything?** Each LoadBalancer Service gets its own
cloud load balancer (cost + one IP per service). With Ingress, **one** controller / load balancer
fronts any number of Services and routes by host and path at Layer 7.
