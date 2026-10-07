# Configuration Issues (CreateContainerConfigError)

Apps get their configuration from **ConfigMaps** and **Secrets**. If a Pod references a ConfigMap/Secret
(or a key inside one) that doesn't exist, the kubelet cannot build the container's environment and the
Pod sits in **CreateContainerConfigError** - the image is fine, the node is fine, the config is wrong.

Namespace: `s14-config`

| File | Description |
|---|---|
| `broken-deployment.yaml` | ConfigMap `app-config` (keys `app_mode`, `log_level`) + Deployment `config-app` that reads key **`mode`** (wrong name) and Secret **`db-credentials`** (never created) |
| `fixed-deployment.yaml` | creates Secret `db-credentials` and reads the correct key `app_mode` |

## 1. Identify the problem

```bash
kubectl create namespace s14-config && kubectl apply -n s14-config -f broken-deployment.yaml
```
![apply](screenshots/01-apply-broken.png)

```bash
kubectl get pods -n s14-config
```
```text
NAME                          READY   STATUS                       RESTARTS   AGE
config-app-687fc6f4c8-bdtr2   0/1     CreateContainerConfigError   0          20m
```
![get pods](screenshots/02-get-pods.png)

## 2. Investigate

```bash
kubectl describe pod -n s14-config -l app=config-app
```
```text
    State:          Waiting
      Reason:       CreateContainerConfigError
Events:
  Normal   Scheduled  20m                   default-scheduler  Successfully assigned s14-config/config-app-687fc6f4c8-bdtr2 to minikube
  Normal   Pulled     9m32s (x12 over 19m)  kubelet            spec.containers{app}: Container image "busybox:1.36" already present on machine ...
  Warning  Failed     9m31s (x12 over 19m)  kubelet            spec.containers{app}: Error: couldn't find key mode in ConfigMap s14-config/app-config
```
![describe](screenshots/03-describe.png)

The event names the exact problem. Check what the referenced objects really contain:
```bash
kubectl get configmap app-config -n s14-config -o yaml | grep -A3 "^data:"
kubectl get secret db-credentials -n s14-config
```
```text
data:
  app_mode: production
  log_level: info
Error from server (NotFound): secrets "db-credentials" not found
```
![check objects](screenshots/04-check-config-objects.png)

## 3. Root cause

Two configuration mistakes in the Deployment:
1. `APP_MODE` reads key `mode` from ConfigMap `app-config`, but the key is called **`app_mode`**.
2. `DB_PASSWORD` reads Secret `db-credentials`, which **does not exist** in the namespace.

(The kubelet reports the first error it hits; fixing only the key would have surfaced
`secret "db-credentials" not found` next - so check *every* reference, not just the one in the event.)

## 4. Fix

```bash
kubectl apply -n s14-config -f fixed-deployment.yaml && kubectl rollout status deployment/config-app -n s14-config --timeout=240s
```
```yaml
# fixed-deployment.yaml - the important changes
kind: Secret
metadata:
  name: db-credentials
stringData:
  password: "s14-demo-only-password"      # demo value only
...
            - name: APP_MODE
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: app_mode            # was: mode
```
```text
secret/db-credentials created
deployment.apps/config-app configured
Waiting for deployment "config-app" rollout to finish: 1 old replicas are pending termination...
error: timed out waiting for the condition
```
![fix](screenshots/05-fix.png)

(The rollout status timed out only because the overloaded node was slow to start the new Pod; the next
check shows it completed.)

## 5. Verify

```bash
kubectl rollout status deployment/config-app -n s14-config --timeout=300s; kubectl get pods -n s14-config; kubectl logs deployment/config-app -n s14-config
```
```text
deployment "config-app" successfully rolled out
NAME                         READY   STATUS    RESTARTS   AGE
config-app-9ff5c65cd-lt6jb   1/1     Running   0          13m
mode=production log=info password-length=22
```
![verify](screenshots/06-verify.png)

The app now sees `APP_MODE=production`, `LOG_LEVEL=info` and a 22-character password from the Secret
(the app prints only the length, never the value).

## Before / after

| | Before | After |
|---|---|---|
| Status | `CreateContainerConfigError` | `Running` |
| Event | `couldn't find key mode in ConfigMap s14-config/app-config` | - |
| App output | (never started) | `mode=production log=info password-length=22` |

## Cleanup (this and the DNS / networking namespaces)
```bash
kubectl delete namespace s14-config s14-dns s14-dns-backend s14-net --wait=false
```
![cleanup](screenshots/07-cleanup.png)

**Configuration checklist:** `describe pod` events -> `kubectl get cm/secret <name> -o yaml` and compare
key names exactly -> check the namespace -> remember env vars are read only at container start (restart
the Pods after changing a ConfigMap used via `env`).
