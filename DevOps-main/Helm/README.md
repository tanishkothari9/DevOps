# Session 15: Helm

> Work in progress: the full write-up for this session is being finalised. Every screenshot below is real output from commands run on a local minikube cluster / Docker / GitHub Actions.

## 01-helm-commands

### 01-helm-version

```bash
helm version
```

![01-helm-version](01-helm-commands/screenshots/01-helm-version.png)

### 02-helm-create

```bash
helm create myapp && ls -R myapp
```

![02-helm-create](01-helm-commands/screenshots/02-helm-create.png)

### 03-chart-files

```bash
cat myapp/Chart.yaml | grep -v "^#" | grep -v "^$"; echo ---; grep -E "^replicaCount|^image:|^  repository|^  tag|^service:|^  type|^  port" myapp/values.yaml
```

![03-chart-files](01-helm-commands/screenshots/03-chart-files.png)

### 04-helm-lint

```bash
helm lint myapp
```

![04-helm-lint](01-helm-commands/screenshots/04-helm-lint.png)

### 05-helm-template

```bash
helm template demo myapp --set replicaCount=2 | grep -E "^# Source|^kind:|replicas:|image:"
```

![05-helm-template](01-helm-commands/screenshots/05-helm-template.png)

### 06-helm-repo-add

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

![06-helm-repo-add](01-helm-commands/screenshots/06-helm-repo-add.png)

### 07-helm-repo-list

```bash
helm repo list
```

![07-helm-repo-list](01-helm-commands/screenshots/07-helm-repo-list.png)

### 08-helm-repo-update

```bash
helm repo update bitnami
```

![08-helm-repo-update](01-helm-commands/screenshots/08-helm-repo-update.png)

### 09-helm-search-repo

```bash
helm search repo bitnami/nginx; echo; helm search repo nginx --versions | head -6
```

![09-helm-search-repo](01-helm-commands/screenshots/09-helm-search-repo.png)

### 10-helm-search-hub

```bash
helm search hub nginx --max-col-width 60 | head -12
```

![10-helm-search-hub](01-helm-commands/screenshots/10-helm-search-hub.png)

### 11-helm-show-chart

```bash
helm show chart bitnami/nginx | head -20
```

![11-helm-show-chart](01-helm-commands/screenshots/11-helm-show-chart.png)

### 12-helm-install

```bash
helm install myapp ./myapp -n s15-helm --create-namespace --set image.tag=1.27
```

![12-helm-install](01-helm-commands/screenshots/12-helm-install.png)

### 13-helm-list

```bash
helm list -n s15-helm; echo; helm list -A | grep -E "NAME|s15"
```

![13-helm-list](01-helm-commands/screenshots/13-helm-list.png)

### 14-kubectl-resources

```bash
kubectl rollout status deployment/myapp -n s15-helm --timeout=240s; kubectl get all -n s15-helm
```

![14-kubectl-resources](01-helm-commands/screenshots/14-kubectl-resources.png)

### 15-helm-status

```bash
helm status myapp -n s15-helm
```

![15-helm-status](01-helm-commands/screenshots/15-helm-status.png)

### 16-helm-get-values

```bash
helm get values myapp -n s15-helm; echo; helm get values myapp -n s15-helm --all | head -20
```

![16-helm-get-values](01-helm-commands/screenshots/16-helm-get-values.png)

### 17-helm-get-manifest

```bash
helm get manifest myapp -n s15-helm | head -60
```

![17-helm-get-manifest](01-helm-commands/screenshots/17-helm-get-manifest.png)

### 18-helm-get-all

```bash
helm get all myapp -n s15-helm | grep -E "^NAME|^LAST DEPLOYED|^NAMESPACE|^STATUS|^REVISION|^CHART|^VERSION|^APP_VERSION|^USER-SUPPLIED VALUES|^COMPUTED VALUES|^HOOKS|^MANIFEST|^NOTES|^# Source"
```

![18-helm-get-all](01-helm-commands/screenshots/18-helm-get-all.png)

### 19-helm-upgrade

```bash
helm upgrade myapp ./myapp -n s15-helm --set image.tag=1.27 --set replicaCount=3
```

![19-helm-upgrade](01-helm-commands/screenshots/19-helm-upgrade.png)

### 20-verify-upgrade

```bash
kubectl rollout status deployment/myapp -n s15-helm --timeout=240s; kubectl get deploy,pods -n s15-helm -o wide; helm get values myapp -n s15-helm
```

![20-verify-upgrade](01-helm-commands/screenshots/20-verify-upgrade.png)

### 21-helm-history

```bash
helm history myapp -n s15-helm
```

![21-helm-history](01-helm-commands/screenshots/21-helm-history.png)

### 22-helm-rollback

```bash
helm rollback myapp 1 -n s15-helm && kubectl rollout status deployment/myapp -n s15-helm --timeout=240s; kubectl get deploy myapp -n s15-helm; helm history myapp -n s15-helm
```

![22-helm-rollback](01-helm-commands/screenshots/22-helm-rollback.png)

### 23-helm-uninstall

```bash
helm uninstall myapp -n s15-helm; helm list -n s15-helm; kubectl get all -n s15-helm
```

![23-helm-uninstall](01-helm-commands/screenshots/23-helm-uninstall.png)
