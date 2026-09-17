# Prometheus 告警规则

`nginx-demo-prometheusrule.yaml` 使用 Prometheus Operator 的 `PrometheusRule` CRD。

先确认集群是否安装了该 CRD：

```bash
kubectl get crd prometheusrules.monitoring.coreos.com
```

如果命令能查到 CRD，再应用规则：

```bash
kubectl apply -f monitoring/alerts/nginx-demo-prometheusrule.yaml
kubectl get prometheusrule -n monitoring
```

本项目使用 Helm Prometheus 时，可能没有安装 Prometheus Operator CRD。此时不要直接执行 `kubectl apply`，可以先保留规则文件，或后续切换到 kube-prometheus-stack 后再启用。

规则中的 Deployment 名称对应下面的安装方式：

```bash
helm upgrade --install nginx-demo deploy/helm/nginx-demo \
  --namespace demo \
  --create-namespace
```
