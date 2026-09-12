# Metrics Server、Prometheus 与 Grafana 故障复盘

## Metrics Server 证书

### 现象

Metrics Server 报错：kubelet serving certificate 不包含节点 IP 的 SAN。

### 处理

实验环境为 Metrics Server 增加 `--kubelet-insecure-tls`，生产环境应正确签发 kubelet serving certificate，而不是长期关闭校验。

### 验证

```bash
kubectl top nodes
kubectl top pods -A
```

## Prometheus PVC Pending

### 根因

集群没有可用 StorageClass，Prometheus 和 Alertmanager 的 PVC 无法绑定。

### 实验处理

暂时关闭持久化：`server.persistentVolume.enabled=false`、`alertmanager.persistence.enabled=false`。后续应补充 StorageClass、PV 和 PVC。

## 镜像和代理

Worker 拉取 quay.io、Docker Hub 镜像时出现超时、EOF 或连接重置。Shell 中设置代理并不会自动传递给 systemd 管理的 containerd，因此需要在 containerd 的 systemd drop-in 中配置 `HTTP_PROXY`、`HTTPS_PROXY` 和 `NO_PROXY`，然后重新加载并重启 containerd。

## 验证链路

```text
Metrics Server → kubectl top
Prometheus → Targets 全部 UP
Grafana → Prometheus Save & Test 成功
Grafana → Dashboard 能显示节点和 Kubernetes 指标
```
