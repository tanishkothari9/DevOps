# Pending Pods

A Pod is **Pending** when it has been accepted by the API server but **the scheduler cannot place it on
any node** (or, briefly, while images are being prepared). It has no IP and no node. The scheduler
always explains why in a `FailedScheduling` event.

Common causes: not enough CPU/memory, `nodeSelector`/affinity that matches no node, taints without
tolerations, a PVC that can't be bound.

Namespace: `s14-pending`

| File | Description |
|---|---|
| `broken-pod.yaml` | `pending-demo` with `nodeSelector: kubernetes.io/hostname: node-that-does-not-exist` (reference) |
| `broken-pod-resources.yaml` | `pending-resources-demo` requesting `cpu: 500` and `memory: 1000Gi` (reference scenario 3) |
| `fixed-pod.yaml` | no nodeSelector |
| `fixed-pod-resources.yaml` | realistic requests/limits (100m CPU / 64Mi) |

## 1. Identify the problem

```bash
kubectl create namespace s14-pending && kubectl apply -n s14-pending -f broken-pod.yaml -f broken-pod-resources.yaml
```
![apply](screenshots/01-apply-broken.png)

```bash
kubectl get pods -n s14-pending -o wide
```
```text
NAME                     READY   STATUS    RESTARTS   AGE     IP       NODE     NOMINATED NODE   READINESS GATES
pending-demo             0/1     Pending   0          2m42s   <none>   <none>   <none>           <none>
pending-resources-demo   0/1     Pending   0          2m42s   <none>   <none>   <none>           <none>
```
![get pods](screenshots/02-get-pods-pending.png)

`NODE <none>` and `IP <none>` after almost 3 minutes: the Pods were never scheduled.

## 2. Investigate

```bash
kubectl describe pod pending-demo -n s14-pending
```
```text
Status:           Pending
Node-Selectors:              kubernetes.io/hostname=node-that-does-not-exist
Events:
  Warning  FailedScheduling  2m48s  default-scheduler  0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector.
           preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
```
![describe selector](screenshots/03-describe-nodeselector.png)

```bash
kubectl describe pod pending-resources-demo -n s14-pending
```
```text
    Requests:
      cpu:        500
      memory:     1000Gi
Events:
  Warning  FailedScheduling  2m20s (x2 over 2m50s)  default-scheduler  0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory.
```
![describe resources](screenshots/04-describe-resources.png)

Compare with what the node actually has:
```bash
kubectl get nodes --show-labels | tr "," "\n" | grep -E "NAME|hostname"
kubectl describe node minikube | grep -A3 "^Allocatable:"
kubectl describe node minikube | grep -A4 "Allocated resources:"
```
```text
kubernetes.io/hostname=minikube
Allocatable:
  cpu:                10
Allocated resources:
  Resource           Requests      Limits
  cpu                4140m (41%)   10 (100%)
```
![node](screenshots/05-node-labels-capacity.png)

## 3. Root cause

| Pod | Root cause |
|---|---|
| `pending-demo` | `nodeSelector` requires `kubernetes.io/hostname=node-that-does-not-exist`; the only node is `minikube` |
| `pending-resources-demo` | Requests 500 CPUs and 1000Gi RAM; the node has 10 CPUs (~5.8 free) and ~8Gi RAM |

## 4. Fix

`nodeSelector` and resource requests can't be changed on an existing Pod, so delete and re-apply:
```bash
kubectl delete pod pending-demo pending-resources-demo -n s14-pending && kubectl apply -n s14-pending -f fixed-pod.yaml -f fixed-pod-resources.yaml
```
![fix](screenshots/06-fix.png)

## 5. Verify

```bash
kubectl get pods -n s14-pending -o wide
```
```text
NAME                     READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
pending-demo             1/1     Running   0          18m   10.244.0.173   minikube   <none>           <none>
pending-resources-demo   1/1     Running   0          18m   10.244.0.174   minikube   <none>           <none>
```
![verify](screenshots/07-verify.png)

Both Pods now have a node and an IP and are `Running`.

## Before / after

| | Before | After |
|---|---|---|
| Status | `Pending`, `NODE <none>` | `Running` on `minikube` |
| Scheduler message | `didn't match Pod's node affinity/selector` / `Insufficient cpu, Insufficient memory` | scheduled normally |
