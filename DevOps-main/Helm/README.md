# Session 15: Helm - Homework

**Helm** is the package manager for Kubernetes. A **chart** is a folder of templated Kubernetes YAML plus
default values; installing a chart creates a **release**; every install/upgrade/rollback of a release
creates a new numbered **revision**, which is what makes one-command rollbacks possible.

All work was done with **Helm v4.3.0** on a local minikube cluster (Kubernetes v1.37). Every command
in the READMEs was actually run and has its real output plus a **screenshot** directly under it; raw
output is in each folder's `outputs/`. Charts come from the instructor's reference repo
(`devops-heros/session-15-helm`) or were generated with `helm create`.

## Contents

| Folder | Task | What's inside |
|---|---|---|
| [`01-helm-commands/`](01-helm-commands/README.md) | **Task 1 - Helm commands** | `create`, `lint`, `template`, `repo add/list/update/remove`, `search repo`, `search hub`, `show chart`, `install`, `list`, `status`, `get values/manifest/all`, `upgrade`, `history`, `rollback`, `uninstall` - 28 screenshots; chart `myapp/` |
| [`02-helm-rollback/`](02-helm-rollback/README.md) | **Task 2 - Rollback workflow** | install -> upgrade -> verify -> upgrade again -> verify -> rollback -> verify, plus a broken-image upgrade rolled back by hand and `--rollback-on-failure`; chart `app-chart/` |
| [`mini-project/`](mini-project/README.md) | **Task 3 - Mini project** | `notes-chart` (Chart.yaml, values.yaml, values-prod.yaml, ConfigMap/Deployment/Service templates): lint, template, install, upgrade to prod, bad upgrade, rollback, uninstall |

## Deliverables checklist

| Deliverable | Where |
|---|---|
| Helm chart | [mini-project/notes-chart/](mini-project/notes-chart/), [02-helm-rollback/app-chart/](02-helm-rollback/app-chart/), [01-helm-commands/myapp/](01-helm-commands/myapp/) |
| values.yaml | [mini-project/notes-chart/values.yaml](mini-project/notes-chart/values.yaml) + [values-prod.yaml](mini-project/notes-chart/values-prod.yaml) |
| Templates | [mini-project/notes-chart/templates/](mini-project/notes-chart/templates/) |
| Installation | [mini-project/README.md#step-10-install-development](mini-project/README.md), [01-helm-commands/README.md](01-helm-commands/README.md) |
| Upgrade | mini-project step 11, rollback workflow steps 2 and 4 |
| Rollback | [02-helm-rollback/README.md](02-helm-rollback/README.md), mini-project step 14 |
| Screenshots | `screenshots/` in every folder |
| README files | this file + one per folder |
| Mini project | [mini-project/](mini-project/) |

---

## Task 1 - Commands at a glance

| Command | What it does | Example I ran |
|---|---|---|
| `helm create` | scaffold a chart | `helm create myapp` |
| `helm install` | create a release (rev 1) | `helm install myapp ./myapp -n s15-helm --create-namespace --set image.tag=1.27` |
| `helm list` | list releases | `helm list -n s15-helm` |
| `helm status` | release status + resources | `helm status myapp -n s15-helm` |
| `helm get` | values / manifest / everything of a release | `helm get values myapp --all`, `helm get manifest myapp`, `helm get all myapp` |
| `helm upgrade` | new revision | `helm upgrade myapp ./myapp --set replicaCount=3` |
| `helm history` | revision list | `helm history myapp` |
| `helm rollback` | redeploy an older revision | `helm rollback myapp 1` |
| `helm uninstall` | delete release + resources | `helm uninstall myapp` |
| `helm repo` | add / list / update / remove repos | `helm repo add bitnami https://charts.bitnami.com/bitnami` |
| `helm search` | find charts in repos / on Artifact Hub | `helm search repo nginx`, `helm search hub nginx` |

![helm status](01-helm-commands/screenshots/15-helm-status.png)
![helm search hub](01-helm-commands/screenshots/10-helm-search-hub.png)

## Task 2 - Rollback workflow at a glance

| Rev | Step | Image | Replicas | Verified with |
|---|---|---|---|---|
| 1 | install | nginx:1.24 | 1 | `kubectl get deploy` + `helm history` |
| 2 | upgrade | nginx:1.25 | 2 | same + `helm get values` |
| 3 | upgrade again | nginx:1.27 | 3 | same |
| 4 | **rollback to 2** | **nginx:1.25** | **2** | same - history shows `Rollback to 2` |

![verify rollback](02-helm-rollback/screenshots/08-verify-rollback.png)

## Task 3 - Mini project at a glance

| Rev | Action | Result |
|---|---|---|
| 1 | `helm install notes-dev notes-chart` | 1 x nginx:1.24, `ENVIRONMENT=development` |
| 2 | `helm upgrade ... -f values-prod.yaml` | 3 x nginx:1.25, `ENVIRONMENT=production` |
| 3 | `helm upgrade ... --set image.tag=broken-tag-does-not-exist` | new Pod `ImagePullBackOff` |
| 4 | `helm rollback notes-dev 2` | 3/3 healthy on nginx:1.25 again |

![mini rollback](mini-project/screenshots/13-verify-rollback.png)

---

## Things I learned / noticed

* `helm upgrade` reports `STATUS: deployed` even when the new Pods can't start - Helm only checks that
  the API accepted the manifests unless you add `--wait` or `--rollback-on-failure`.
* A rollback never rewrites history: it adds a new revision ("Rollback to N").
* Helm 4 renamed `--atomic` to `--rollback-on-failure` (it implies `--wait`).
* `helm template` + `helm lint` catch most chart mistakes without a cluster.
* `helm get values` shows only what *you* overrode; `--all` shows the merged result.

## Note on the environment

The minikube node was shared with other workloads and badly overloaded at times. One real effect is
kept in the evidence: the first `helm rollback` in Task 1 failed with an API-server `TLS handshake
timeout` (recorded by Helm as a `failed` revision); I re-ran the cycle once the API server recovered and
it succeeded. The `--rollback-on-failure` demo also ran out of its 90s wait while the node was slow to
terminate Pods - explained in the rollback README. The `bitnami` repo I added for the `helm repo` /
`helm search` practice was removed again at the end (`helm repo remove bitnami`), and all `s15-*`
namespaces were deleted.
