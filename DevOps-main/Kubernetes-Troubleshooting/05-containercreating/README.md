# Stuck in ContainerCreating

**ContainerCreating** is normally a short phase: the Pod is scheduled and the kubelet is pulling the image,
setting up the network and **mounting volumes**. If a Pod *stays* there, something the container needs
before it can start is missing. A classic cause: the Pod mounts a **ConfigMap or Secret that doesn't exist**.

Namespace: `s14-cc`

| File | Description |
|---|---|
| `broken-pod.yaml` | nginx Pod that mounts ConfigMap `site-content` as its web root - the ConfigMap was never created |
| `configmap.yaml` | the missing ConfigMap `site-content` (the fix) |

## 1. Identify the problem

```bash
kubectl create namespace s14-cc && kubectl apply -n s14-cc -f broken-pod.yaml
```
![apply](screenshots/01-apply-broken.png)

```bash
kubectl get pods -n s14-cc
```
```text
NAME                 READY   STATUS              RESTARTS   AGE
config-volume-demo   0/1     ContainerCreating   0          11m
```
![get pods](screenshots/02-get-pods.png)

11 minutes in `ContainerCreating` - far longer than an image pull of a cached image should take.

## 2. Investigate

```bash
kubectl describe pod config-volume-demo -n s14-cc
```
```text
    State:          Waiting
      Reason:       ContainerCreating
Volumes:
  site-config:
    Type:      ConfigMap (a volume populated by a ConfigMap)
    Name:      site-content
    Optional:  false
Events:
  Normal   Scheduled    11m                   default-scheduler  Successfully assigned s14-cc/config-volume-demo to minikube
  Warning  FailedMount  35s (x12 over 9m57s)  kubelet            MountVolume.SetUp failed for volume "site-config" : configmap "site-content" not found
```
![describe](screenshots/03-describe.png)

```bash
kubectl get configmap -n s14-cc; kubectl get configmap site-content -n s14-cc
```
```text
NAME               DATA   AGE
kube-root-ca.crt   1      11m
Error from server (NotFound): configmaps "site-content" not found
```
![check configmap](screenshots/04-check-configmap.png)

No `kubectl logs` here - the container never started, so there are no logs. `describe` / events is the
only place the answer shows up.

## 3. Root cause

The Pod mounts ConfigMap `site-content` (`Optional: false`), but that ConfigMap does not exist in the
namespace, so the kubelet keeps retrying `MountVolume.SetUp` and never starts the container.

## 4. Fix

Create the missing ConfigMap (alternatives: fix the name in the Pod, or mark the volume `optional: true`
if the app can live without it):
```bash
kubectl apply -n s14-cc -f configmap.yaml
```
```text
configmap/site-content created
```
![fix](screenshots/05-fix-create-configmap.png)

No need to recreate the Pod - the kubelet retries the mount and starts the container on its own.

## 5. Verify

```bash
kubectl get pods -n s14-cc; kubectl describe pod config-volume-demo -n s14-cc | grep -A6 "^Events:" | tail -3; kubectl exec config-volume-demo -n s14-cc -- curl -s localhost
```
```text
NAME                 READY   STATUS    RESTARTS   AGE
config-volume-demo   1/1     Running   0          38m
  Warning  FailedMount   22m (x14 over 37m)   kubelet  MountVolume.SetUp failed for volume "site-config" : configmap "site-content" not found
  Normal   Pulled        18m                  kubelet  spec.containers{nginx}: Container image "nginx:1.27" already present on machine ...
  Normal   Created       18m                  kubelet  spec.containers{nginx}: Container created
<h1>Served from the site-content ConfigMap</h1>
```
![verify](screenshots/06-verify.png)

The events show the transition: `FailedMount` x14, then `Pulled`/`Created` right after the ConfigMap
appeared, and nginx serves the page from the ConfigMap.

## Before / after

| | Before | After |
|---|---|---|
| Status | `ContainerCreating` (11+ min) | `Running` |
| Event | `FailedMount ... configmap "site-content" not found` | `Created` / `Started` |
| `curl localhost` | (no container) | `<h1>Served from the site-content ConfigMap</h1>` |

Note the difference from [09-configuration](../09-configuration/README.md): a missing ConfigMap used as
a **volume** gives `ContainerCreating` + `FailedMount`; a missing ConfigMap/Secret **key used as an env
var** gives `CreateContainerConfigError`.
