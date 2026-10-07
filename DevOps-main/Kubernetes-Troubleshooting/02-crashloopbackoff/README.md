# CrashLoopBackOff

**CrashLoopBackOff** means the container starts, exits (crashes), Kubernetes restarts it, it crashes
again... and the kubelet waits longer and longer between restarts (10s, 20s, 40s ... up to 5 min).
The image is fine and the Pod is scheduled - the **process itself** keeps dying.

Namespace: `s14-crash`

| File | Description |
|---|---|
| `broken-pod.yaml` | `crash-demo`: busybox prints two lines and `exit 1` (reference repo) |
| `broken-app-missing-env.yaml` | `crash-env-demo`: Python app that exits because `DATABASE_URL` is not set (reference scenario 1) |
| `fixed-pod.yaml` | `crash-demo` that keeps running (`sleep 3600`) |
| `fixed-app-with-env.yaml` | `crash-env-demo` with `DATABASE_URL` provided via `env` |

## 1. Identify the problem

```bash
kubectl create namespace s14-crash && kubectl apply -n s14-crash -f broken-pod.yaml -f broken-app-missing-env.yaml
```
![apply](screenshots/01-apply-broken.png)

```bash
kubectl get pods -n s14-crash
```
```text
NAME             READY   STATUS             RESTARTS        AGE
crash-demo       0/1     CrashLoopBackOff   4 (6s ago)      10m
crash-env-demo   0/1     Error              2 (4m12s ago)   10m
```
![get pods](screenshots/02-get-pods-crashloop.png)

`RESTARTS` keeps climbing and the status flips between `Error` (just exited) and `CrashLoopBackOff`
(waiting before the next restart).

## 2. Investigate

```bash
kubectl describe pod crash-demo -n s14-crash
```
```text
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
      Started:      Thu, 08 Oct 2026 00:03:44 +0530
      Finished:     Thu, 08 Oct 2026 00:03:44 +0530
    Ready:          False
    Restart Count:  4
```
![describe](screenshots/03-describe.png)

`Last State: Terminated, Exit Code: 1`, started and finished in the same second: the process itself exits
with an error. Exit code tells you the class of problem: `1` = app error, `137` = killed (OOMKilled /
SIGKILL), `127` = command not found.

The current container has no useful logs yet, so read the logs of the **previous** (crashed) container:
```bash
kubectl logs crash-demo -n s14-crash --previous
```
```text
Application starting...
Something went wrong!
```
![logs previous](screenshots/04-logs-previous.png)

```bash
kubectl logs crash-env-demo -n s14-crash --previous
kubectl get pod crash-env-demo -n s14-crash -o jsonpath="{.status.containerStatuses[0].lastState.terminated.reason} exitCode={.status.containerStatuses[0].lastState.terminated.exitCode}"
```
```text
[FATAL ERROR]: DATABASE_URL environment variable is MISSING!
Error exitCode=1
```
![logs env](screenshots/05-logs-env-app.png)

## 3. Root cause

| Pod | Root cause |
|---|---|
| `crash-demo` | The container command ends with `exit 1` - the "application" fails every time it starts. |
| `crash-env-demo` | The app requires the env var `DATABASE_URL`; it is not defined in the Pod spec, so the app exits with code 1 on startup. |

## 4. Fix

A Pod's command/env cannot be edited in place, so delete and re-create with the fixed manifests
(with a Deployment you would just `kubectl apply` the fixed template):
```bash
kubectl delete pod crash-demo crash-env-demo -n s14-crash && kubectl apply -n s14-crash -f fixed-pod.yaml -f fixed-app-with-env.yaml
```
```yaml
# fixed-app-with-env.yaml (the important part)
      env:
        - name: DATABASE_URL
          value: "postgres://db.s14-crash.svc.cluster.local:5432/app"
```
![fix](screenshots/06-fix-delete-apply.png)

## 5. Verify

```bash
kubectl get pods -n s14-crash; kubectl logs crash-demo -n s14-crash; kubectl logs crash-env-demo -n s14-crash
```
```text
NAME             READY   STATUS    RESTARTS   AGE
crash-demo       1/1     Running   0          75s
crash-env-demo   1/1     Running   0          75s

Application starting...
Application is healthy
Application started successfully! DATABASE_URL=postgres://db.s14-crash.svc.cluster.local:5432/app
```
![verify](screenshots/07-verify-fixed.png)

Both Pods are `Running` with `0` restarts.

## Before / after

| | Before | After |
|---|---|---|
| Status | `CrashLoopBackOff` / `Error` | `Running` |
| Restarts | 4 and climbing | 0 |
| Logs | `Something went wrong!` / `DATABASE_URL ... MISSING!` | `Application is healthy` / `started successfully!` |

**Checklist for CrashLoopBackOff:** `kubectl logs --previous` -> exit code in `describe` -> check
command/args, env vars, ConfigMaps/Secrets, and liveness probes (a bad liveness probe also causes
restarts - see Session 13 probes).
