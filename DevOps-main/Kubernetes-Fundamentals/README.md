# Session 09: Kubernetes Fundamentals - Homework

Hands-on with a local **minikube** cluster: install/configure, verify the cluster, explore the
architecture, practise the basic objects and commands, and work through the official
[Kubernetes Basics tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/).

Every output below is real (trimmed where long). Each command has its screenshot underneath;
full text of every command's output is in [`outputs/`](outputs/).

| Item | Value (from my cluster) |
|---|---|
| Machine | MacBook, Apple Silicon (**arm64**) |
| minikube | v1.39.0, **docker** driver, **containerd** runtime |
| Kubernetes | server **v1.37.0**, kubectl client v1.37.1 |
| Node | 1 node `minikube`, IP 192.168.49.2, 10 CPU / ~8 GiB visible |
| Addons | metrics-server, ingress, storage-provisioner, default-storageclass |
| My namespaces | `s09-basics`, `s09-tutorial` (deleted at the end) |

> The cluster is shared with my other homework sessions, so you will see other namespaces
> (`argocd`, `monitoring`, `s13-*` ...) in some cluster-wide listings.

---

## Task 1: Install and configure Minikube

Install (macOS, Homebrew) and start a cluster:

```bash
brew install minikube kubectl
minikube start --driver=docker --cpus=6 --memory=6500 \
  --addons=metrics-server,ingress,storage-provisioner,default-storageclass
```

`--driver=docker` runs the whole Kubernetes node as one Docker container (no VM needed on a Mac);
the addons give me metrics (`kubectl top`), an NGINX Ingress controller and dynamic PersistentVolumes.

### Tool versions
```bash
kubectl version && minikube version && docker version --format "Docker server: {{.Server.Version}}"
```
```
Client Version: v1.37.1
Kustomize Version: v5.8.1
Server Version: v1.37.0
minikube version: v1.39.0
Docker server: 29.1.5
```
![tool versions](screenshots/01-tool-versions.png)

### minikube status / profile / addons
```bash
minikube status
minikube profile list
minikube addons list | grep -E "ADDON NAME|enabled"
```
```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured

│ PROFILE  │ DRIVER │  RUNTIME   │      IP      │ VERSION │ STATUS │ NODES │ ACTIVE PROFILE │ ACTIVE KUBECONTEXT │
│ minikube │ docker │ containerd │ 192.168.49.2 │ v1.37.0 │ OK     │ 1     │ *              │ *                  │
```
![minikube status](screenshots/02-minikube-status.png)
![minikube profile list](screenshots/03-minikube-profile-list.png)
![minikube addons](screenshots/04-minikube-addons.png)

> Observation: `minikube addons list` only showed metrics-server, storage-provisioner and
> default-storageclass as "enabled" at this moment, although the `ingress-nginx` controller Pod
> (installed by `--addons=ingress` at start) was already Running - see `kubectl get pods -A` below.

### kubectl context
```bash
kubectl config current-context && kubectl config get-contexts
```
```
minikube
CURRENT   NAME       CLUSTER    AUTHINFO   NAMESPACE
*         minikube   minikube   minikube   default
```
![context](screenshots/05-kubectl-context.png)

---

## Task 2: Verify Kubernetes cluster status

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
kubectl api-resources | head -45
```
```
Kubernetes control plane is running at https://127.0.0.1:50992
CoreDNS is running at https://127.0.0.1:50992/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

NAME       STATUS   ROLES           AGE     VERSION   INTERNAL-IP    ...  OS-IMAGE                         KERNEL-VERSION             CONTAINER-RUNTIME
minikube   Ready    control-plane   8m43s   v1.37.0   192.168.49.2   ...  Debian GNU/Linux 12 (bookworm)   6.12.65-linuxkit (arm64)   containerd://2.3.4
```
![cluster-info](screenshots/06-cluster-info.png)
![nodes](screenshots/07-get-nodes-wide.png)
![all pods](screenshots/08-get-pods-all.png)
![api-resources](screenshots/09-api-resources.png)

**Observation:** the node is `Ready`, the API server answers on a port forwarded from the
minikube container (`127.0.0.1:50992`), and every system Pod in `kube-system` is Running.
`kubectl api-resources` lists every object type the API server knows (pods, services,
deployments, configmaps, ...) with its short name, API group and whether it is namespaced.

---

## Task 3: Explore Kubernetes architecture

```
                       +------------------ CONTROL PLANE (minikube node) ------------------+
 kubectl  --HTTPS-->   | kube-apiserver <---> etcd (cluster state, key-value store)        |
                       |      ^   ^                                                         |
                       |      |   +---- kube-scheduler (picks a node for new Pods)          |
                       |      +-------- kube-controller-manager (Deployment, ReplicaSet,    |
                       |                 Node, EndpointSlice ... control loops)            |
                       +-------------------------------------------------------------------+
                       +---------------------- WORKER NODE (same node here) ---------------+
                       | kubelet (node agent, talks to the API server, runs Pods via CRI)  |
                       | container runtime: containerd  (pulls images, runs containers)    |
                       | kube-proxy (programs iptables rules for Services)                 |
                       | CNI: kindnet (Pod networking 10.244.0.0/24)                       |
                       +-------------------------------------------------------------------+
```

| Component | Where it runs in minikube | Job |
|---|---|---|
| **kube-apiserver** | static Pod `kube-apiserver-minikube` | Front door of the cluster. Every `kubectl` call and every component talks only to it; validates and stores objects in etcd |
| **etcd** | static Pod `etcd-minikube` | Consistent key-value store - the *only* place cluster state is saved |
| **kube-scheduler** | static Pod `kube-scheduler-minikube` | Watches for Pods with no node and picks the best node (resources, affinity, taints) |
| **kube-controller-manager** | static Pod `kube-controller-manager-minikube` | Runs the control loops that make *actual state = desired state* (ReplicaSet, Deployment, Node, Job, EndpointSlice controllers ...) |
| **kubelet** | systemd service on the node (not a Pod) | Node agent: receives Pods assigned to its node, asks the runtime to start containers, runs probes, reports status |
| **kube-proxy** | DaemonSet Pod `kube-proxy-*` | Implements Services: writes iptables rules that send ClusterIP/NodePort traffic to Pod IPs |
| **container runtime** | containerd 2.3.4 | Pulls images and runs containers (kubelet talks to it through the CRI) |
| **CoreDNS** | Deployment `coredns` | Cluster DNS (service discovery) |
| **CNI (kindnet)** | DaemonSet `kindnet` | Gives every Pod an IP and connects Pods across nodes |

### Proof from the cluster

```bash
kubectl get pods -n kube-system -o wide
kubectl get pods -n kube-system -l tier=control-plane -L component
```
```
NAME                               READY   STATUS    RESTARTS   AGE     COMPONENT
etcd-minikube                      1/1     Running   0          9m11s   etcd
kube-apiserver-minikube            1/1     Running   0          9m5s    kube-apiserver
kube-controller-manager-minikube   1/1     Running   0          9m10s   kube-controller-manager
kube-scheduler-minikube            1/1     Running   0          9m3s    kube-scheduler
```
![kube-system pods](screenshots/10-kube-system-pods.png)
![control plane pods](screenshots/11-control-plane-pods.png)

The control-plane components are **static Pods**: the kubelet starts them directly from YAML
files on the node's disk, not from the API server:

```bash
minikube ssh -- sudo ls -l /etc/kubernetes/manifests
```
```
-rw------- 1 root root 2655 Oct  7 16:55 etcd.yaml
-rw------- 1 root root 4171 Oct  7 16:55 kube-apiserver.yaml
-rw------- 1 root root 3254 Oct  7 16:55 kube-controller-manager.yaml
-rw------- 1 root root 1727 Oct  7 16:55 kube-scheduler.yaml
```
![static pod manifests](screenshots/12-static-pod-manifests.png)

The **kubelet** is not a Pod - it is a systemd service on the node:
```bash
minikube ssh -- "sudo SYSTEMD_URLIZE=0 systemctl status kubelet --no-pager | head -11"
```
```
● kubelet.service - kubelet: The Kubernetes Node Agent
     Loaded: loaded (/lib/systemd/system/kubelet.service; disabled; preset: enabled)
     Active: active (running) since Wed 2026-10-07 16:55:34 UTC; 10min ago
   Main PID: 1408 (kubelet)
```
![kubelet](screenshots/13-kubelet-service.png)

The **container runtime** (containerd, via `crictl`) shows the real containers behind the Pods:
```bash
minikube ssh -- sudo crictl ps | head -14
```
![crictl ps](screenshots/14-container-runtime.png)

**kube-proxy** and the CNI run as **DaemonSets** (one Pod per node):
```bash
kubectl get daemonsets -n kube-system -o wide
```
```
NAME         DESIRED   CURRENT   READY   ...  CONTAINERS    IMAGES
kindnet      1         1         1       ...  kindnet-cni   docker.io/kindest/kindnetd:v20260820-69b56db7
kube-proxy   1         1         1       ...  kube-proxy    registry.k8s.io/kube-proxy:v1.37.0
```
![daemonsets](screenshots/15-daemonsets-kube-proxy.png)

The API server's own health checks include **etcd**:
```bash
kubectl get --raw="/readyz?verbose" | head -25
```
```
[+]ping ok
[+]log ok
[+]etcd ok
[+]etcd-readiness ok
[+]informer-sync ok
...
```
![readyz](screenshots/16-apiserver-readyz.png)

Node capacity and the runtime/kubelet versions reported by the kubelet:
```bash
kubectl describe node minikube | sed -n "/^Capacity:/,/^Non-terminated/p"
```
![describe node](screenshots/17-describe-node.png)

---

## Task 4: Basic Kubernetes objects and commands

YAML files are in [`basic-objects/`](basic-objects/):

| File | Object | What it shows |
|---|---|---|
| [`pod.yaml`](basic-objects/pod.yaml) | Pod | smallest deployable unit (1 nginx container) |
| [`replicaset.yaml`](basic-objects/replicaset.yaml) | ReplicaSet | keeps 3 copies alive (self-healing) |
| [`deployment.yaml`](basic-objects/deployment.yaml) | Deployment | manages ReplicaSets (updates/rollbacks) |
| [`service.yaml`](basic-objects/service.yaml) | Service (ClusterIP) | stable IP + DNS name for the Deployment's Pods |

### Namespace + Pod
```bash
kubectl create namespace s09-basics && kubectl get namespaces
kubectl apply -f basic-objects/pod.yaml -n s09-basics
kubectl wait --for=condition=Ready pod/nginx-pod -n s09-basics --timeout=180s
kubectl get pods -n s09-basics -o wide --show-labels
```
```
pod/nginx-pod created
pod/nginx-pod condition met
NAME        READY   STATUS    RESTARTS   AGE     IP            NODE       ...   LABELS
nginx-pod   1/1     Running   0          2m25s   10.244.0.17   minikube   ...   app=nginx-pod
```
![namespace](screenshots/18-create-namespace.png)
![apply pod](screenshots/19-apply-pod.png)

```bash
kubectl describe pod nginx-pod -n s09-basics   # (trimmed to the key sections)
```
```
Events:
  Normal  Scheduled  2m35s  default-scheduler  Successfully assigned s09-basics/nginx-pod to minikube
  Normal  Pulling    2m31s  kubelet            Pulling image "nginx:1.25-alpine"
  Normal  Pulled     15s    kubelet            Successfully pulled image "nginx:1.25-alpine" in 1m17.413s ...
  Normal  Created    14s    kubelet            Container created
  Normal  Started    12s    kubelet            Container started
```
![describe pod](screenshots/20-describe-pod.png)

The events show the architecture in action: **scheduler** assigns the Pod, **kubelet** pulls the
image through **containerd**, creates and starts the container.

```bash
kubectl logs nginx-pod -n s09-basics --tail=5
kubectl exec nginx-pod -n s09-basics -- nginx -v
kubectl exec nginx-pod -n s09-basics -- hostname
```
```
2026/10/07 17:09:02 [notice] 1#1: start worker process 39
nginx version: nginx/1.25.5
nginx-pod
```
![logs exec](screenshots/21-logs-exec.png)

### ReplicaSet and self-healing
```bash
kubectl apply -f basic-objects/replicaset.yaml -n s09-basics
kubectl get rs,pods -l app=nginx-rs -n s09-basics -o wide
POD=$(kubectl get pods -l app=nginx-rs -n s09-basics -o jsonpath="{.items[0].metadata.name}")
kubectl delete pod $POD -n s09-basics
kubectl get pods -l app=nginx-rs -n s09-basics -o wide
```
```
Deleting nginx-rs-58fpf
pod "nginx-rs-58fpf" deleted from s09-basics namespace
NAME             READY   STATUS    RESTARTS   AGE   IP
nginx-rs-6n5f6   1/1     Running   0          81s   10.244.0.47
nginx-rs-smkfv   1/1     Running   0          34s   10.244.0.50     <-- brand-new replacement Pod
nginx-rs-zm55v   1/1     Running   0          81s   10.244.0.46
NAME       DESIRED   CURRENT   READY   AGE
nginx-rs   3         3         3       82s
```
![replicaset](screenshots/22-apply-replicaset.png)
![self healing](screenshots/23-replicaset-self-healing.png)

**Observation:** I deleted a Pod, and the ReplicaSet controller immediately created a new one
(new name, new IP) to get back to `replicas: 3`. A bare Pod (like `nginx-pod`) would not come back.

### Deployment + Service
```bash
kubectl apply -f basic-objects/deployment.yaml -f basic-objects/service.yaml -n s09-basics
kubectl rollout status deployment/web -n s09-basics
kubectl get deploy,rs,pods -l app=web -n s09-basics
kubectl get svc web-svc -n s09-basics
kubectl exec nginx-pod -n s09-basics -- wget -qO- http://web-svc | head -4
```
```
deployment.apps/web   2/2     2            2           31s
replicaset.apps/web-65878c78cc   2         2         2       32s
pod/web-65878c78cc-bc654   1/1     Running   0          31s
pod/web-65878c78cc-lvqc9   1/1     Running   0          32s
web-svc   ClusterIP   10.110.243.20   <none>        80/TCP    33s

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```
![deployment + service](screenshots/24-apply-deployment-service.png)
![curl service](screenshots/25-curl-service-from-pod.png)

**Observation:** the Deployment created a ReplicaSet (`web-65878c78cc`, the suffix is the
pod-template hash) which created the Pods. Another Pod reached them by the **Service name**
`web-svc` thanks to CoreDNS.

### Inspecting objects
```bash
kubectl get deployment web -n s09-basics -o yaml | sed -n "1,25p"
kubectl explain deployment.spec.replicas
```
![yaml + explain](screenshots/26-get-yaml-explain.png)

`-o yaml` shows the full object as stored (including defaults the API server added, e.g.
`strategy.rollingUpdate.maxSurge: 25%`, `revisionHistoryLimit: 10`); `kubectl explain` documents any field.

### Cleanup
```bash
kubectl delete -f basic-objects/ -n s09-basics && kubectl get all -n s09-basics
```
![cleanup basics](screenshots/27-cleanup-basics.png)

### Command cheat-sheet I used

| Command | Purpose |
|---|---|
| `kubectl get <kind> [-o wide / -o yaml / -L label / --show-labels]` | list objects |
| `kubectl describe <kind> <name>` | details + events (first stop for debugging) |
| `kubectl apply -f file.yaml` / `kubectl delete -f file.yaml` | declarative create/update/delete |
| `kubectl create deployment / expose / scale / set image` | imperative shortcuts |
| `kubectl logs <pod>` / `kubectl exec <pod> -- <cmd>` | look inside a running container |
| `kubectl rollout status / history / undo` | manage Deployment rollouts |
| `kubectl explain <field.path>` | built-in API documentation |
| `kubectl api-resources` | every object type the cluster supports |

---

## Task 5: Kubernetes Basics tutorial (hands-on)

Namespace `s09-tutorial`. I followed the six tutorial modules.

### Module 2 - Deploy an app (first attempt with the tutorial image)
```bash
kubectl create namespace s09-tutorial
kubectl create deployment kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1 -n s09-tutorial
kubectl get deployments -n s09-tutorial
```
```
deployment.apps/kubernetes-bootcamp created
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   0/1     1            0           34s
```
![create deployment](screenshots/30-tutorial-create-deployment.png)
![get deployments](screenshots/31-tutorial-get-deployments.png)

`kubectl proxy` exposes the API server on localhost so it can be called with curl:
```bash
kubectl proxy --port=8011 & curl -s http://localhost:8011/version
```
```
{
  "major": "1",
  "minor": "37",
  "gitVersion": "v1.37.0",
  "platform": "linux/arm64"
}
        "name": "kubernetes-bootcamp-5cc66bcc9b-gtqzw",
```
![kubectl proxy](screenshots/32-tutorial-kubectl-proxy.png)

The Pod never became ready:
```bash
kubectl get pods -n s09-tutorial -o wide
kubectl logs deploy/kubernetes-bootcamp -n s09-tutorial
```
```
kubernetes-bootcamp-5cc66bcc9b-gtqzw   0/1     CrashLoopBackOff   3 (63s ago)   3m22s
exec /bin/sh: exec format error
node arch: arm64
image arch:
			"architecture": "amd64",
```
![describe crashing pod](screenshots/33-tutorial-get-describe-pods.png)
![exec format error](screenshots/34-tutorial-arm64-exec-format-error.png)

**Root cause:** `gcr.io/google-samples/kubernetes-bootcamp:v1` (and the tutorial's `v2`
image `docker.io/jocatalin/kubernetes-bootcamp:v2`) are published **only for amd64**, but my
minikube node is **arm64** (Apple Silicon) -> `exec format error`, exit code 255, CrashLoopBackOff.
**Fix:** use a multi-arch image that behaves the same way (small HTTP server that prints which
Pod answered): `traefik/whoami` (published for amd64 + arm64). All tutorial steps below are
unchanged apart from the image name (and `--target-port 80`, because whoami listens on 80).

```bash
kubectl delete deployment kubernetes-bootcamp -n s09-tutorial
kubectl create deployment kubernetes-bootcamp --image=traefik/whoami:v1.10.1 -n s09-tutorial
kubectl rollout status deployment/kubernetes-bootcamp -n s09-tutorial
kubectl get deployments,pods -n s09-tutorial -o wide
```
```
deployment.apps/kubernetes-bootcamp created
deployment "kubernetes-bootcamp" successfully rolled out
NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES
deployment.apps/kubernetes-bootcamp   1/1     1            1           29s   whoami       traefik/whoami:v1.10.1
pod/kubernetes-bootcamp-5bcf65bf6d-2llhl   1/1     Running   0          29s   10.244.0.76   minikube
```
![recreate with multi-arch image](screenshots/35-tutorial-recreate-with-multiarch-image.png)

### Module 3 - Explore the app (pods, describe, logs, exec)
```bash
kubectl get pods -n s09-tutorial -o wide
kubectl describe pods -n s09-tutorial
POD_NAME=$(kubectl get pods -n s09-tutorial -o go-template --template "{{range .items}}{{.metadata.name}}{{\"\n\"}}{{end}}")
kubectl logs $POD_NAME -n s09-tutorial
```
```
POD_NAME=kubernetes-bootcamp-5bcf65bf6d-2llhl
2026/10/07 17:47:48 Starting up on port 80
```
![explore pods](screenshots/36-tutorial-explore-pods.png)
![logs](screenshots/37-tutorial-logs.png)

The tutorial runs `kubectl exec -ti $POD_NAME -- bash` and curls `localhost` inside the Pod.
`traefik/whoami` is built `FROM scratch` (no shell, no curl), so I used the Kubernetes way of
debugging minimal images - an **ephemeral debug container** that shares the Pod's network:
```bash
kubectl debug -q -i $POD_NAME -n s09-tutorial --image=busybox:1.36 --target=whoami -- \
  sh -c "hostname; wget -qO- http://localhost:80"
```
```
kubernetes-bootcamp-5bcf65bf6d-2llhl

Hostname: kubernetes-bootcamp-5bcf65bf6d-2llhl
IP: 10.244.0.76
GET / HTTP/1.1
Host: localhost:80
User-Agent: Wget
```
![kubectl debug](screenshots/38-tutorial-debug-container.png)

### Module 4 - Expose the app with a Service, labels
```bash
kubectl expose deployment/kubernetes-bootcamp --type="NodePort" --port 8080 --target-port 80 -n s09-tutorial
kubectl get services -n s09-tutorial
kubectl describe services/kubernetes-bootcamp -n s09-tutorial
```
```
NAME                  TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
kubernetes-bootcamp   NodePort   10.106.225.171   <none>        8080:30473/TCP   4s
...
Endpoints:                10.244.0.76:80
```
![expose](screenshots/39-tutorial-expose-nodeport.png)

```bash
NODE_PORT=$(kubectl get services/kubernetes-bootcamp -n s09-tutorial -o go-template="{{(index .spec.ports 0).nodePort}}")
minikube ssh -- curl -s http://$(minikube ip):$NODE_PORT
```
```
NODE_PORT=30473  MINIKUBE_IP=192.168.49.2
Hostname: kubernetes-bootcamp-5bcf65bf6d-2llhl
```
![curl nodeport](screenshots/40-tutorial-curl-nodeport.png)

> With the docker driver on macOS the node IP (192.168.49.2) is not routable from the Mac, so I
> curl it from inside the node with `minikube ssh` (or use `minikube service <name> --url`).

Labels:
```bash
kubectl describe deployment kubernetes-bootcamp -n s09-tutorial | grep -E "^Labels|^Selector"
kubectl get pods -l app=kubernetes-bootcamp -n s09-tutorial
kubectl get services -l app=kubernetes-bootcamp -n s09-tutorial
kubectl label pods $POD_NAME version=v1 -n s09-tutorial
kubectl get pods -l version=v1 -n s09-tutorial
```
```
pod/kubernetes-bootcamp-5bcf65bf6d-2llhl labeled
Labels:           app=kubernetes-bootcamp
                  pod-template-hash=5bcf65bf6d
                  version=v1
NAME                                   READY   STATUS    RESTARTS   AGE
kubernetes-bootcamp-5bcf65bf6d-2llhl   1/1     Running   0          118s
```
![labels](screenshots/41-tutorial-labels.png)
![add label](screenshots/42-tutorial-add-label.png)

Deleting the Service:
```bash
kubectl delete service -l app=kubernetes-bootcamp -n s09-tutorial
minikube ssh -- curl -s -m 3 http://$(minikube ip):$NODE_PORT     # fails now
minikube ssh -- curl -s http://$POD_IP:80                          # the Pod itself still works
```
```
NodePort before delete: 31036
service "kubernetes-bootcamp" deleted from s09-tutorial namespace
--- curl the old NodePort now fails:
ssh: Process exited with status 7
=> connection failed (Service is gone)
--- but the app is still running inside the pod (curl the pod IP from the node):
Hostname: kubernetes-bootcamp-5bcf65bf6d-2llhl
```
![delete service](screenshots/43-tutorial-delete-service.png)

> Note: I had re-created the Service once before this capture (an earlier attempt of this step
> had a scripting bug in how I read the NodePort), which is why the NodePort here is 31036.

**Observation:** the Service is only the network entry point. Removing it cuts external access,
but the Deployment and its Pod keep running.

### Module 5 - Scale the app
```bash
kubectl expose deployment/kubernetes-bootcamp --type="NodePort" --port 8080 --target-port 80 -n s09-tutorial
kubectl get rs -n s09-tutorial
kubectl scale deployments/kubernetes-bootcamp --replicas=4 -n s09-tutorial
kubectl get deployments,rs -n s09-tutorial
kubectl get pods -o wide -n s09-tutorial
```
```
deployment.apps/kubernetes-bootcamp   4/4     4            4           2m43s
replicaset.apps/kubernetes-bootcamp-5bcf65bf6d   4         4         4       2m43s
kubernetes-bootcamp-5bcf65bf6d-2llhl   1/1     Running   0          2m43s   10.244.0.76
kubernetes-bootcamp-5bcf65bf6d-5n6qh   1/1     Running   0          5s      10.244.0.77
kubernetes-bootcamp-5bcf65bf6d-9s295   1/1     Running   0          5s      10.244.0.78
kubernetes-bootcamp-5bcf65bf6d-zn429   1/1     Running   0          5s      10.244.0.79
```
![re-expose](screenshots/44-tutorial-re-expose.png)
![scale up](screenshots/45-tutorial-scale-up.png)

```bash
kubectl describe deployments/kubernetes-bootcamp -n s09-tutorial    # events
kubectl get endpointslices -n s09-tutorial
```
```
Replicas:               4 desired | 4 updated | 4 total | 4 available | 0 unavailable
  Normal  ScalingReplicaSet  8s     deployment-controller  Scaled up replica set kubernetes-bootcamp-5bcf65bf6d from 1 to 4
kubernetes-bootcamp-t9hdj   IPv4   80   10.244.0.76,10.244.0.77,10.244.0.78 + 1 more...
```
![scale events](screenshots/46-tutorial-scale-events.png)

**Load balancing** - 12 requests to the NodePort were spread over the 4 Pods:
```bash
minikube ssh -- "for i in \$(seq 1 12); do curl -s http://192.168.49.2:$NODE_PORT | grep Hostname; done" | sort | uniq -c
```
```
   5 Hostname: kubernetes-bootcamp-5bcf65bf6d-2llhl
   1 Hostname: kubernetes-bootcamp-5bcf65bf6d-5n6qh
   5 Hostname: kubernetes-bootcamp-5bcf65bf6d-9s295
   1 Hostname: kubernetes-bootcamp-5bcf65bf6d-zn429
```
![load balancing](screenshots/47-tutorial-load-balancing.png)

Scale down:
```bash
kubectl scale deployments/kubernetes-bootcamp --replicas=2 -n s09-tutorial
kubectl get pods -o wide -n s09-tutorial
```
```
kubernetes-bootcamp   2/2     2            2           2m58s
kubernetes-bootcamp-5bcf65bf6d-2llhl   1/1     Running   0          2m59s
kubernetes-bootcamp-5bcf65bf6d-5n6qh   0/1     Error     0          21s     <-- being removed
kubernetes-bootcamp-5bcf65bf6d-9s295   1/1     Running   0          21s
```
![scale down](screenshots/48-tutorial-scale-down.png)

(The removed Pods briefly show `Error` because the whoami process exits with a non-zero code
when it receives SIGTERM; they disappear a few seconds later.)

### Module 6 - Rolling update and rollback
```bash
kubectl set image deployments/kubernetes-bootcamp whoami=traefik/whoami:v1.10.3 -n s09-tutorial
kubectl rollout status deployments/kubernetes-bootcamp -n s09-tutorial
kubectl get rs,pods -n s09-tutorial
```
```
deployment.apps/kubernetes-bootcamp image updated
Waiting for deployment "kubernetes-bootcamp" rollout to finish: 1 out of 2 new replicas have been updated...
deployment "kubernetes-bootcamp" successfully rolled out
replicaset.apps/kubernetes-bootcamp-5888b75678   2         2         2       50s     <-- new (v1.10.3)
replicaset.apps/kubernetes-bootcamp-5bcf65bf6d   0         0         0       4m2s    <-- old, kept for rollback
```
![rolling update](screenshots/49-tutorial-rolling-update.png)

```bash
kubectl describe pods -n s09-tutorial | grep -E "^Name:|Image:"
kubectl rollout history deployment/kubernetes-bootcamp -n s09-tutorial
```
```
Name:             kubernetes-bootcamp-5888b75678-4ggt6
    Image:          traefik/whoami:v1.10.3
Name:             kubernetes-bootcamp-5888b75678-9kws2
    Image:          traefik/whoami:v1.10.3
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```
![verify update](screenshots/50-tutorial-verify-update.png)

A bad update (the tutorial uses the non-existent tag `v10`):
```bash
kubectl set image deployments/kubernetes-bootcamp whoami=traefik/whoami:v10 -n s09-tutorial
kubectl get deployments -n s09-tutorial
kubectl get pods -n s09-tutorial
```
```
kubernetes-bootcamp   2/2     1            2           4m43s
kubernetes-bootcamp-5888b75678-4ggt6   1/1     Running            0          90s
kubernetes-bootcamp-5888b75678-9kws2   1/1     Running            0          68s
kubernetes-bootcamp-7648ff76c4-9d9z2   0/1     ImagePullBackOff   0          24s
```
![bad update](screenshots/51-tutorial-bad-update.png)
![bad update describe](screenshots/52-tutorial-bad-update-describe.png)

```bash
kubectl get events -n s09-tutorial --sort-by=.lastTimestamp | grep -E "Failed|BackOff" | tail -4
```
```
Warning   Failed   pod/kubernetes-bootcamp-7648ff76c4-9d9z2   Failed to pull image "traefik/whoami:v10": rpc error: code = NotFound
          desc = failed to pull and unpack image "docker.io/traefik/whoami:v10": ... not found
```
![bad update events](screenshots/52b-tutorial-bad-update-events.png)

**Observation:** the rolling update protects the app - only ONE new Pod was created and it is
stuck in `ImagePullBackOff`; the two old Pods are still Running, so the app stays up (2/2 available).

Rollback:
```bash
kubectl rollout undo deployments/kubernetes-bootcamp -n s09-tutorial
kubectl get pods -n s09-tutorial
kubectl describe pods -n s09-tutorial | grep "Image:"
kubectl rollout history deployment/kubernetes-bootcamp -n s09-tutorial
```
```
deployment.apps/kubernetes-bootcamp rolled back
deployment "kubernetes-bootcamp" successfully rolled out
kubernetes-bootcamp-5888b75678-4ggt6   1/1     Running       0          94s
kubernetes-bootcamp-5888b75678-9kws2   1/1     Running       0          72s
kubernetes-bootcamp-7648ff76c4-9d9z2   0/1     Terminating   0          28s
REVISION  CHANGE-CAUSE
1         <none>
3         <none>
4         <none>
```
![rollout undo](screenshots/53-tutorial-rollout-undo.png)

`rollout undo` went back to the previous revision (v1.10.3); revision 2 was re-numbered to 4.

### Cleanup
```bash
kubectl delete namespace s09-tutorial s09-basics
```
![cleanup](screenshots/54-cleanup.png)

---

## Short notes on Kubernetes architecture

- **Kubernetes is declarative.** I store the *desired state* (YAML) through the **API server**
  into **etcd**; controllers continuously compare it with the *actual state* and fix differences
  (that is why the deleted ReplicaSet Pod came back by itself).
- **Control plane** = API server (the only component that talks to etcd), etcd (state),
  scheduler (decides *where* a Pod runs), controller-manager (control loops: ReplicaSet,
  Deployment, Node, EndpointSlice, Job ...). In minikube these are static Pods on the single node.
- **Worker node** = kubelet (runs and watches Pods, executes probes), container runtime
  (containerd - pulls images and runs containers via the CRI), kube-proxy (Service routing with
  iptables), plus a CNI plugin for Pod networking (kindnet here) and CoreDNS for service discovery.
- **Flow of `kubectl create deployment`:** kubectl -> API server -> etcd; Deployment controller
  creates a ReplicaSet; ReplicaSet controller creates Pods; scheduler binds each Pod to a node;
  kubelet on that node asks containerd to pull the image and start the container; kubelet
  reports status back; EndpointSlice controller adds the ready Pod to the Service; kube-proxy
  updates iptables so traffic can reach it.
- **Objects:** Pod (containers sharing network/storage) -> ReplicaSet (N copies) -> Deployment
  (versions, rolling update, rollback) -> Service (stable IP/DNS + load balancing); Namespaces
  separate them logically.
- **Lesson learned:** container images are CPU-architecture specific. On Apple Silicon check
  that the image is published for `arm64` (or is multi-arch), otherwise the container dies with
  `exec format error`.
