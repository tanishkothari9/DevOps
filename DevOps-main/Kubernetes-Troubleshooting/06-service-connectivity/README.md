# Service Connectivity Issues

The Pods are `Running`, but calling them **through the Service** fails. A Service finds its Pods with a
**label selector** and forwards to the **targetPort**. If either is wrong, traffic goes nowhere.

Namespace: `s14-svc`

| File | Description |
|---|---|
| `deployment.yaml` | `web` Deployment, 2 nginx replicas, label `app=web`, container port 80 (reference) |
| `broken-service-selector.yaml` | **Bug 1** - selector `app: web-ahsgdf` (typo, from the reference `service.yaml`) |
| `broken-service-targetport.yaml` | **Bug 2** - selector fixed, but `targetPort: 8080` (nginx listens on 80) |
| `fixed-service.yaml` | selector `app: web`, `targetPort: 80` |
| `client-pod.yaml` | `curlimages/curl` Pod used to test from inside the cluster |

## 1. Identify the problem

```bash
kubectl create namespace s14-svc && kubectl apply -n s14-svc -f deployment.yaml -f broken-service-selector.yaml -f client-pod.yaml
```
![apply](screenshots/01-apply-app-broken-service.png)

```bash
kubectl get pods,svc -n s14-svc -o wide --show-labels
```
```text
NAME                       READY   STATUS    RESTARTS   AGE   IP             ...   LABELS
pod/client                 1/1     Running   0          18m   10.244.0.166   ...   <none>
pod/web-557577df75-6xnmt   1/1     Running   0          18m   10.244.0.164   ...   app=web,pod-template-hash=557577df75
pod/web-557577df75-sp596   1/1     Running   0          18m   10.244.0.165   ...   app=web,pod-template-hash=557577df75

NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE   SELECTOR         LABELS
service/web-service   ClusterIP   10.106.236.18   <none>        80/TCP    18m   app=web-ahsgdf   <none>
```
![get all](screenshots/02-get-all.png)

Everything looks healthy, but:
```bash
kubectl exec client -n s14-svc -- curl -s -m 5 http://web-service; echo "curl exit code: $?"
```
```text
command terminated with exit code 7
curl exit code: 7
```
![test](screenshots/03-test-connection.png)

curl exit code 7 = *failed to connect*.

## 2. Investigate - Bug 1: selector mismatch

```bash
kubectl get endpointslices -n s14-svc -l kubernetes.io/service-name=web-service
kubectl describe svc web-service -n s14-svc | grep -E "Selector|TargetPort|Endpoints"
```
```text
NAME                ADDRESSTYPE   PORTS     ENDPOINTS   AGE
web-service-m4nqv   IPv4          <unset>   <unset>     19m
Selector:                 app=web-ahsgdf
TargetPort:               80/TCP
Endpoints:
```
![no endpoints](screenshots/04-endpoints-empty.png)

**No endpoints.** Compare the selector with the Pod labels:
```bash
kubectl get pods -n s14-svc -l app=web --show-labels; kubectl get pods -n s14-svc -l app=web-ahsgdf
```
```text
NAME                   READY   STATUS    RESTARTS   AGE   LABELS
web-557577df75-6xnmt   1/1     Running   0          19m   app=web,pod-template-hash=557577df75
web-557577df75-sp596   1/1     Running   0          19m   app=web,pod-template-hash=557577df75

No resources found in s14-svc namespace.
```
![labels](screenshots/05-compare-labels.png)

**Root cause 1:** the Service selects `app=web-ahsgdf`, but the Pods are labelled `app=web`. No Pod
matches, so the Service has zero endpoints.

## 3. Bug 2: selector right, targetPort wrong

```bash
kubectl apply -n s14-svc -f broken-service-targetport.yaml && sleep 3 && kubectl describe svc web-service -n s14-svc | grep -E "Selector|TargetPort|Endpoints"
```
```text
service/web-service configured
Selector:                 app=web
TargetPort:               8080/TCP
Endpoints:                10.244.0.164:8080,10.244.0.165:8080
```
![targetport bug](screenshots/06-apply-targetport-bug.png)

Now there ARE endpoints - but on port 8080:
```bash
kubectl exec client -n s14-svc -- curl -sS -m 5 http://web-service
kubectl get pod <web-pod> -n s14-svc -o jsonpath="{.spec.containers[0].ports}"
kubectl exec <web-pod> -n s14-svc -- sh -c "cat /proc/net/tcp | awk 'NR>1 && \$4==\"0A\" {print \$2}'"   # listening sockets
```
```text
curl: (7) Failed to connect to web-service port 80 after 7 ms: Couldn't connect to server
curl exit code: 7
[{"containerPort":80,"protocol":"TCP"}]
00000000:0050
```
![connection refused](screenshots/07-test-connection-refused.png)

`00000000:0050` = listening on `0.0.0.0:80` (0x50 = 80). **Root cause 2:** the Service forwards to
port 8080, but nginx only listens on 80, so the connection is refused even though endpoints exist.

## 4. Fix

```bash
kubectl apply -n s14-svc -f fixed-service.yaml && sleep 3 && kubectl describe svc web-service -n s14-svc | grep -E "Selector|TargetPort|Endpoints"
```
```text
service/web-service configured
Selector:                 app=web
TargetPort:               80/TCP
Endpoints:                10.244.0.164:80,10.244.0.165:80
```
![fix](screenshots/08-fix.png)

## 5. Verify

```bash
kubectl exec client -n s14-svc -- curl -s -m 5 http://web-service | head -4
kubectl exec client -n s14-svc -- curl -s -m 5 -o /dev/null -w "HTTP %{http_code} ...\n" http://web-service.s14-svc.svc.cluster.local
```
```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
HTTP 200 from web-service.s14-svc.svc.cluster.local
```
![verify](screenshots/09-verify.png)

## Before / after

| | Bug 1 (selector) | Bug 2 (targetPort) | Fixed |
|---|---|---|---|
| Selector | `app=web-ahsgdf` | `app=web` | `app=web` |
| Endpoints | *(none)* | `10.244.0.164:8080, .165:8080` | `10.244.0.164:80, .165:80` |
| curl | exit 7 | exit 7 (connection refused) | HTTP 200 |

**Checklist:** `kubectl get endpointslices` / `describe svc` -> empty? compare `selector` with
`kubectl get pods --show-labels` -> endpoints present but failing? compare `targetPort` with the
container's listening port.
