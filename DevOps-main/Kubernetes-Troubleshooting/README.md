# Session 14: Kubernetes Troubleshooting - Homework

> "My Kubernetes application is not working. How do I find out why?"

Every problem below was **actually reproduced** on a local minikube cluster (Kubernetes v1.37, containerd,
kindnet CNI), investigated with real commands, fixed and verified. Each command in the sub-READMEs has its
real output and a **screenshot** directly under it; raw output is in each folder's `outputs/`.
Manifests come from the instructor's reference repo (`devops-heros/session-14-kubernetes-troubleshooting`)
where they exist; the rest were written for this homework.

## The method I followed for every issue

```text
GET -> DESCRIBE -> EVENTS -> LOGS -> EXEC -> TEST -> ROOT CAUSE -> FIX -> VERIFY
```

1. **Identify** - `kubectl get pods -o wide` (status, restarts, IP, node)
2. **Investigate** - `kubectl describe` (state, last state, exit code, **Events**), `kubectl events`,
   `kubectl logs [--previous]`, `kubectl exec` (curl / nslookup / netstat from inside)
3. **Root cause** - name the exact misconfiguration
4. **Fix** - smallest change that removes the cause
5. **Verify** - re-run the same checks and show the "after" state

## Contents

| Folder | Topic | Problem reproduced -> root cause |
|---|---|---|
| [`01-kubectl-commands/`](01-kubectl-commands/README.md) | **Task 1** - `get`, `describe`, `logs`, `exec`, `events`, `explain`, `top`, `get -o wide` | 26 commands with real output |
| [`02-crashloopbackoff/`](02-crashloopbackoff/README.md) | CrashLoopBackOff | app `exit 1` / missing `DATABASE_URL` env var |
| [`03-imagepullbackoff-errimagepull/`](03-imagepullbackoff-errimagepull/README.md) | ImagePullBackOff + ErrImagePull | non-existent tag (`not found`) / non-existent repo (`pull access denied`) |
| [`04-pending/`](04-pending/README.md) | Pending | `nodeSelector` matching no node / requests of 500 CPU + 1000Gi |
| [`05-containercreating/`](05-containercreating/README.md) | ContainerCreating | Pod mounts a ConfigMap that doesn't exist (`FailedMount`) |
| [`06-service-connectivity/`](06-service-connectivity/README.md) | Service connectivity | wrong selector (no endpoints) / wrong `targetPort` (connection refused) |
| [`07-dns/`](07-dns/README.md) | DNS | short name used across namespaces (NXDOMAIN) + a real CoreDNS outage |
| [`08-pod-networking/`](08-pod-networking/README.md) | Pod networking | app bound to `127.0.0.1` / default-deny NetworkPolicy |
| [`09-configuration/`](09-configuration/README.md) | Configuration | wrong ConfigMap key + missing Secret (`CreateContainerConfigError`) |
| [`mini-project/`](mini-project/README.md) | **Task 3 - Mini project** | broken image Pod + Service selector challenge, with Q&A and troubleshooting table |
| [`scenarios/`](scenarios/README.md) | Reference "triage gauntlet" | 5 broken Pods at once incl. OOMKilled (exit 137) and a silent DNS failure |

## Summary table - every issue

| Issue | What I saw | Command that revealed it | Root cause | Fix | Verified |
|---|---|---|---|---|---|
| CrashLoopBackOff | `0/1 CrashLoopBackOff`, restarts 4+ | `kubectl logs --previous` -> `DATABASE_URL ... MISSING!` | app exits 1 | add env var / fix command | `Running`, 0 restarts |
| ErrImagePull | `ErrImagePull` | `kubectl describe pod` events: `... not found` | tag doesn't exist | `nginx:1.27` | `Running` |
| ImagePullBackOff | `ImagePullBackOff` after retries | events: `Back-off pulling image`, `pull access denied` | repo doesn't exist | `kubectl set image` | `Running` |
| Pending | `Pending`, `NODE <none>` | events: `didn't match ... node affinity/selector`, `Insufficient cpu` | bad nodeSelector / huge requests | remove selector / sane requests | `Running` on minikube |
| ContainerCreating | stuck 11+ min | events: `FailedMount ... configmap "site-content" not found` | missing ConfigMap volume | create ConfigMap | `Running`, page served from ConfigMap |
| Service (selector) | curl exit 7, `Endpoints:` empty | `describe svc` vs `get pods --show-labels` | `app=web-ahsgdf` vs `app=web` | fix selector | endpoints back, HTTP 200 |
| Service (targetPort) | endpoints on `:8080`, refused | Pod `containerPort 80`, socket `:0050` | targetPort 8080 vs 80 | `targetPort: 80` | HTTP 200 |
| DNS | `wget: bad address 'orders-api'` | `nslookup` -> NXDOMAIN, `/etc/resolv.conf` search domains | short name, Service in other namespace | FQDN `orders-api.s14-dns-backend.svc.cluster.local` | frontend logs `OK` |
| Pod networking (bind) | curl to Pod IP refused | `netstat -tln` -> `127.0.0.1:8080` | app listens on loopback only | `--bind 0.0.0.0` | HTTP 200 from client |
| Pod networking (policy) | curl timeout (exit 28) | `kubectl get/describe networkpolicy` | default-deny ingress | allow `role=client` -> 8080 | client 200, others still blocked |
| Configuration | `CreateContainerConfigError` | events: `couldn't find key mode in ConfigMap` | wrong key + missing Secret | key `app_mode` + create Secret | logs `mode=production ...` |

![crashloop](02-crashloopbackoff/screenshots/02-get-pods-crashloop.png)
![service no endpoints](06-service-connectivity/screenshots/04-endpoints-empty.png)
![networkpolicy verify](08-pod-networking/screenshots/11-verify-allowed.png)

## Deliverables checklist

| Deliverable | Where |
|---|---|
| Commands | [01-kubectl-commands/README.md](01-kubectl-commands/README.md) + the investigation steps of every issue |
| Problem statement / Investigation steps / Root cause / Solution | sections 1-5 of every issue README |
| Before/after output | a "Before / after" table and before + after screenshots in every issue README |
| Screenshots | `screenshots/` in every folder (one per command) |
| Mini project | [mini-project/README.md](mini-project/README.md) (Q1-Q5, troubleshooting table, 10 README questions) |

## Note on the environment

The minikube node was shared with several other workloads (~90 Pods on one node, host load average
20-40). That produced some real, unplanned incidents that are documented where they happened: the node
going `NotReady`, CoreDNS becoming unready (every DNS lookup failed with `connection refused`), and
metrics-server crash-looping (so `kubectl top` was often unavailable). Those turned into extra
troubleshooting practice - see the notes in `01-kubectl-commands`, `07-dns` and `08-pod-networking`.
All `s14-*` namespaces were deleted after the evidence was captured.
