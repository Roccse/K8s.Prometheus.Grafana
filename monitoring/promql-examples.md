# PromQL 查询示例

在 Grafana 的 `Explore → Prometheus → Code` 中执行以下查询。

## 采集目标

```promql
up
```

返回值为 `1` 表示对应采集目标可用。

## Pod 状态

```promql
kube_pod_status_phase
```

按命名空间和 Pod 过滤：

```promql
kube_pod_status_phase{namespace="default", pod=~"nginx-demo.*"}
```

## 容器内存

```promql
container_memory_working_set_bytes
```

换算为 MiB：

```promql
container_memory_working_set_bytes / 1024 / 1024
```

## 容器 CPU 趋势

```promql
rate(container_cpu_usage_seconds_total[5m])
```

## Deployment 副本

```promql
kube_deployment_status_replicas_available
```

```promql
kube_deployment_spec_replicas
```

## Pod 重启

```promql
kube_pod_container_status_restarts_total
```

## 面试时的解释框架

```text
指标名称 → 指标来源 → 标签过滤 → 时间窗口 → 面板展示 → 异常阈值
```

例如，`rate(...[5m])` 不是查询当前累计 CPU，而是计算最近 5 分钟的每秒增长速率，更适合画趋势图和配置告警。
