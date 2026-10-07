# ErrImagePull and ImagePullBackOff

The kubelet could not download the container image.

* **ErrImagePull** - the pull just failed (first attempt / latest attempt).
* **ImagePullBackOff** - after repeated failures the kubelet *backs off* and waits longer before trying
  again. Same problem, later stage. In the output below you can see the same Pod move from one to the other.

Common causes: typo in the image name, tag that doesn't exist, private registry without
`imagePullSecrets`, registry rate-limit / no network.

Namespace: `s14-image`

| File | Description |
|---|---|
| `broken-pod.yaml` | `image-demo` uses `nginx:this-image-does-not-exist` (tag doesn't exist) |
| `broken-pod-bad-repo.yaml` | `image-repo-demo` uses `yatri-api-service:v999-...` (repository doesn't exist) |
| `fixed-pod.yaml` | `image-demo` with `nginx:1.27` |

## 1. Identify the problem

```bash
kubectl create namespace s14-image && kubectl apply -n s14-image -f broken-pod.yaml -f broken-pod-bad-repo.yaml
```
![apply](screenshots/01-apply-broken.png)

First look - **ErrImagePull**:
```bash
kubectl get pods -n s14-image
```
```text
NAME              READY   STATUS              RESTARTS   AGE
image-demo        0/1     ErrImagePull        0          2m43s
image-repo-demo   0/1     ContainerCreating   0          2m42s
```
![ErrImagePull](screenshots/02-get-pods-errimagepull.png)

About a minute later - `image-demo` is in **ImagePullBackOff** and `image-repo-demo` reached **ErrImagePull**:
```text
NAME              READY   STATUS             RESTARTS   AGE
image-demo        0/1     ImagePullBackOff   0          3m36s
image-repo-demo   0/1     ErrImagePull       0          3m35s
```

## 2. Investigate

```bash
kubectl describe pod image-demo -n s14-image
```
```text
    State:          Waiting
      Reason:       ImagePullBackOff
Events:
  Normal   BackOff    kubelet  Back-off pulling image "nginx:this-image-does-not-exist"
  Warning  Failed     kubelet  Error: ImagePullBackOff
  Normal   Pulling    kubelet  Pulling image "nginx:this-image-does-not-exist"
  Warning  Failed     kubelet  Failed to pull image "nginx:this-image-does-not-exist": rpc error: code = NotFound desc = failed to pull and unpack image
                               "docker.io/library/nginx:this-image-does-not-exist": failed to resolve reference ...: not found
  Warning  Failed     kubelet  Error: ErrImagePull
```
![describe](screenshots/03-describe-events.png)

```bash
kubectl describe pod image-repo-demo -n s14-image | grep -E "Image:|Reason:"
kubectl events -n s14-image --for pod/image-repo-demo | tail -5
```
```text
    Image:          yatri-api-service:v999-invalid-tag-does-not-exist
      Reason:       ErrImagePull
Warning   Failed   Pod/image-repo-demo   Failed to pull image "yatri-api-service:v999-invalid-tag-does-not-exist": ...
  "docker.io/library/yatri-api-service:v999-invalid-tag-does-not-exist": pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed
```
![bad repo](screenshots/04-describe-bad-repo.png)

Confirm on the node which tag really exists (pull directly with the container runtime):
```bash
minikube ssh "sudo crictl pull nginx:1.27" 2>&1 | tail -1
minikube ssh "sudo crictl pull nginx:this-image-does-not-exist" 2>&1 | grep -o "not found" | head -1
```
```text
Image is up to date for sha256:7791402a0bf5691936db0f42d40032ac6fb8441867416053f3ea06199de3e7e4
not found
```
![check tag](screenshots/05-check-tag-exists.png)

## 3. Root cause

| Pod | Error message | Root cause |
|---|---|---|
| `image-demo` | `...nginx:this-image-does-not-exist: not found` | The **tag** does not exist in the `nginx` repository |
| `image-repo-demo` | `pull access denied, repository does not exist or may require authorization` | The **repository** `docker.io/library/yatri-api-service` does not exist (or is private and needs `imagePullSecrets`) |

The two messages are worth remembering: **`not found`** = wrong tag; **`pull access denied`** = wrong
repository name or missing registry credentials.

## 4. Fix

Two ways - recreate from the fixed manifest, or patch the image in place (the `image` field is one of the
few Pod fields that can be changed on a running Pod):
```bash
kubectl delete pod image-demo -n s14-image && kubectl apply -n s14-image -f fixed-pod.yaml && kubectl set image pod/image-repo-demo web-app=nginx:1.27 -n s14-image
```
```text
pod "image-demo" deleted from s14-image namespace
pod/image-demo created
pod/image-repo-demo image updated
```
![fix](screenshots/06-fix.png)

## 5. Verify

```bash
kubectl get pods -n s14-image
```
```text
NAME              READY   STATUS    RESTARTS   AGE
image-demo        1/1     Running   0          10m
image-repo-demo   1/1     Running   0          21m
image-repo-demo image now: nginx:1.27
```
![verify](screenshots/07-verify.png)

## Before / after

| | Before | After |
|---|---|---|
| `image-demo` | `ErrImagePull` -> `ImagePullBackOff` (`nginx:this-image-does-not-exist`) | `Running` (`nginx:1.27`) |
| `image-repo-demo` | `ErrImagePull` (`yatri-api-service:v999-...`) | `Running` (`nginx:1.27`, patched with `kubectl set image`) |
