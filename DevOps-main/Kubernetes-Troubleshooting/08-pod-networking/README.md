# Pod Networking Issues

Every Pod gets its own IP and any Pod can reach any other Pod's IP directly - **unless** something gets
in the way. Two common real-world causes, both reproduced here in namespace `s14-net`:

1. The application only listens on **127.0.0.1** (loopback) inside its container, so it is unreachable
   on the Pod IP.
2. A **NetworkPolicy** isolates the Pod and drops the traffic.

| File | Description |
|---|---|
| `broken-server.yaml` | `api-server`: `python3 -m http.server 8080 --bind 127.0.0.1` |
| `fixed-server.yaml` | same, but `--bind 0.0.0.0` |
| `client-pod.yaml` | `client` Pod (label `role=client`) with curl |
| `deny-all-networkpolicy.yaml` | default-deny **ingress** for every Pod in the namespace |
| `allow-client-networkpolicy.yaml` | allow `role=client` -> `app=api-server` on TCP 8080 |

---

## Problem 1: app bound to localhost

### Identify
```bash
kubectl create namespace s14-net && kubectl apply -n s14-net -f broken-server.yaml -f client-pod.yaml
```
![apply](screenshots/01-apply-broken-server.png)

```bash
kubectl get pods -n s14-net -o wide
```
```text
NAME         READY   STATUS    RESTARTS   AGE   IP             NODE
api-server   1/1     Running   0          34m   10.244.0.169   minikube
client       1/1     Running   0          34m   10.244.0.171   minikube
```
![pods](screenshots/02-get-pods.png)

Both Pods are healthy, yet the client can't connect to the server's Pod IP:
```bash
IP=$(kubectl get pod api-server -n s14-net -o jsonpath="{.status.podIP}")
kubectl exec client -n s14-net -- curl -sS -m 5 http://$IP:8080/
```
```text
api-server pod IP: 10.244.0.169
curl: (7) Failed to connect to 10.244.0.169 port 8080 after 1 ms: Couldn't connect to server
curl exit code: 7
```
![cannot connect](screenshots/03-client-cannot-connect.png)

`after 1 ms` + *couldn't connect* = the packet reached the Pod and was **actively refused** (a firewall
drop would time out instead). So nothing is listening on `10.244.0.169:8080`.

### Investigate (from inside the Pod)
```bash
kubectl exec api-server -n s14-net -- wget -qO- http://localhost:8080/ | head -3
```
```text
wget: can't connect to remote host: Connection refused
```
![inside](screenshots/04-works-inside-pod.png)

Interesting - even `localhost` is refused: busybox `wget` resolved `localhost` to the IPv6 `::1` first,
and the app isn't listening there either. The socket table tells the full story:
```bash
kubectl exec api-server -n s14-net -- netstat -tln
kubectl get pod api-server -n s14-net -o jsonpath="{.spec.containers[0].command}"
```
```text
Proto Recv-Q Send-Q Local Address           Foreign Address         State
tcp        0      0 127.0.0.1:8080          0.0.0.0:*               LISTEN
["python3","-m","http.server","8080","--bind","127.0.0.1"]
```
![netstat](screenshots/05-netstat.png)

### Root cause
The server listens on `127.0.0.1:8080` only (`--bind 127.0.0.1`). Loopback is private to the Pod's own
network namespace, so connections to the **Pod IP** are refused. (Containers often default to
`localhost` in dev configs - e.g. Flask's `app.run()` or Vite.)

### Fix
Bind to all interfaces:
```bash
kubectl delete pod api-server -n s14-net && kubectl apply -n s14-net -f fixed-server.yaml && kubectl wait --for=condition=Ready pod/api-server -n s14-net --timeout=300s && kubectl get pods -n s14-net -o wide
```
```text
pod "api-server" deleted from s14-net namespace
pod/api-server created
pod/api-server condition met
NAME         READY   STATUS    RESTARTS   AGE   IP             NODE
api-server   1/1     Running   0          14s   10.244.0.218   minikube
```
![fix](screenshots/06-fix.png)

### Verify
```bash
kubectl exec client -n s14-net -- curl -sS -m 5 http://$IP:8080/ | head -4
kubectl exec api-server -n s14-net -- netstat -tln
kubectl logs api-server -n s14-net
```
```text
api-server pod IP: 10.244.0.218
<!DOCTYPE HTML>
<html lang="en">
<head>
<meta charset="utf-8">
tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN
10.244.0.171 - - [07/Oct/2026 19:20:14] "GET / HTTP/1.1" 200 -
```
![verify](screenshots/07-verify.png)

Now listening on `0.0.0.0:8080` and the server log shows the request from the client's IP `10.244.0.171`.

> Note: my very first check right after the fix (14 seconds after the Pod started) still failed - the
> Pod was "Ready" (it has no readiness probe) but Python hadn't opened the socket yet on the overloaded
> node. A readiness probe (`tcpSocket: 8080`) would prevent a Pod from being marked Ready before it
> actually listens.

---

## Problem 2: NetworkPolicy blocking traffic

### Identify
Someone applies a "default deny" policy to the namespace:
```bash
kubectl apply -n s14-net -f deny-all-networkpolicy.yaml && kubectl get networkpolicy -n s14-net
kubectl exec client -n s14-net -- curl -sS -m 5 -o /dev/null -w "HTTP %{http_code}\n" http://$IP:8080/
```
```text
networkpolicy.networking.k8s.io/default-deny-ingress created
NAME                   POD-SELECTOR   AGE
default-deny-ingress   <none>         1s
HTTP 000
curl: (28) Connection timed out after 5038 milliseconds
curl exit code: 28
```
![deny](screenshots/08-apply-deny-all.png)

This time the symptom is different: **timeout** (exit 28), not *connection refused* - packets are being
silently dropped. (minikube's CNI here is kindnet, which enforces NetworkPolicy.)

### Investigate
```bash
kubectl get networkpolicy -n s14-net; kubectl describe networkpolicy default-deny-ingress -n s14-net; kubectl get pods -n s14-net --show-labels
```
```text
Spec:
  PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
  Allowing ingress traffic:
    <none> (Selected pods are isolated for ingress connectivity)
  Policy Types: Ingress
NAME         READY   STATUS    RESTARTS   AGE     LABELS
api-server   1/1     Running   0          2m48s   app=api-server
client       1/1     Running   0          46m     role=client
```
![investigate](screenshots/09-investigate-netpol.png)

### Root cause
`default-deny-ingress` selects **all** Pods (`podSelector: {}`) and allows **no** ingress, so every
connection into `api-server` is dropped.

### Fix
Keep the default-deny (it's a good security baseline) and add an explicit allow rule for the client:
```bash
kubectl apply -n s14-net -f allow-client-networkpolicy.yaml && kubectl describe networkpolicy allow-client-to-api -n s14-net
```
```text
Spec:
  PodSelector:     app=api-server
  Allowing ingress traffic:
    To Port: 8080/TCP
    From:
      PodSelector: role=client
  Policy Types: Ingress
```
![allow](screenshots/10-fix-allow-policy.png)

### Verify
```bash
kubectl exec client -n s14-net -- curl ... http://$IP:8080/
kubectl run intruder -n s14-net --image=curlimages/curl:8.6.0 --restart=Never --rm -i -- curl ... http://$IP:8080/
```
```text
client (role=client) -> api-server: HTTP 200
curl: (28) Connection timed out after 5001 milliseconds
intruder (no label) -> api-server: HTTP 000
intruder curl exit: 28
```
![verify allowed](screenshots/11-verify-allowed.png)

The labelled client gets HTTP 200, while a Pod without the `role=client` label is still blocked - the
policy works exactly as intended.

## Before / after

| | Before | After |
|---|---|---|
| Problem 1 listen address | `127.0.0.1:8080` -> curl exit 7 (refused) | `0.0.0.0:8080` -> HTTP 200 |
| Problem 2 policy | default-deny only -> curl exit 28 (timeout) | + `allow-client-to-api` -> client HTTP 200, others blocked |

**Networking checklist:** `kubectl get pods -o wide` (IPs) -> curl the Pod IP from another Pod ->
*refused* = nothing listening (check `netstat`, bind address, containerPort) / *timeout* = something
dropping packets (check `kubectl get networkpolicy`, CNI) -> then test the Service and DNS.
