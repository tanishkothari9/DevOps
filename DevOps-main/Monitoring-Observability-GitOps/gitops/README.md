# GitOps with Argo CD

Argo CD watches **this GitHub repository** and keeps the `s20-gitops` namespace of the cluster
identical to what is committed under [`app/`](app/).

```text
You  ->  git push  ->  GitHub  ->  Argo CD detects change  ->  Kubernetes updated automatically
```

## Layout

```text
gitops/
├── README.md                  <- this file
├── argocd-application.yaml    <- tells Argo CD WHERE to look (applied once, by hand)
└── app/                       <- the desired state Argo CD syncs
    ├── namespace.yaml         <- Namespace s20-gitops
    ├── deployment.yaml        <- nginx Deployment s20-gitops-app (replicas + image live here)
    └── service.yaml           <- ClusterIP Service s20-gitops-app
```

| File | What it is | Who applies it |
|---|---|---|
| `app/namespace.yaml`, `app/deployment.yaml`, `app/service.yaml` | The actual application | **Argo CD**, automatically, from Git |
| `argocd-application.yaml` | Argo CD `Application` pointing at `app/` in this repo | **Me, once** (`kubectl apply`) |

`argocd-application.yaml` is deliberately kept **outside** `app/`, so Argo CD does not try to manage its own definition.

## The Application

```yaml
source:
  repoURL: https://github.com/tanishkothari9/DevOps.git
  targetRevision: main
  path: DevOps-main/Monitoring-Observability-GitOps/gitops/app
destination:
  server: https://kubernetes.default.svc
  namespace: s20-gitops
syncPolicy:
  automated:
    prune: true      # delete cluster objects whose YAML was removed from Git
    selfHeal: true   # undo manual kubectl changes (drift) back to what Git says
  syncOptions:
    - CreateNamespace=true
```

## How to use it

```bash
# 1. Install Argo CD (once)
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Register the app (once)
kubectl apply -f gitops/argocd-application.yaml
kubectl get applications -n argocd

# 3. From now on, change the cluster ONLY through Git
#    edit app/deployment.yaml (replicas / image) -> git commit -> git push
#    Argo CD polls every ~3 min; force an immediate check with:
kubectl annotate application s20-gitops-app -n argocd argocd.argoproj.io/refresh=hard --overwrite

# UI (optional)
kubectl port-forward svc/argocd-server -n argocd 18443:443      # https://localhost:18443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

The full live demo (initial sync, Git-driven change, self-heal) with screenshots of every command
is in the main [README](../README.md#task-3-gitops).
