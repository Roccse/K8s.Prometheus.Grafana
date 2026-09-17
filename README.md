# Kubernetes 云原生监控与故障排查实验平台

这是一个面向云原生实习求职的本地 Kubernetes 实验项目。项目以双节点 kubeadm 集群为基础，完成容器化应用部署、Service 暴露、滚动更新、故障自愈，以及 Prometheus + Grafana 监控链路建设。

在基础实验之上，项目增加了 Helm 配置化部署、健康检查、滚动发布、GitHub Actions 镜像流水线、Prometheus 告警样例和可重复的故障演练。增强内容仍明确标注本地实验边界，不把单控制平面环境包装成生产级高可用平台。

## 项目亮点

- 使用 kubeadm 搭建双节点 Kubernetes 集群（Control Plane + Worker）。
- 使用 Flannel 提供 Pod 网络，验证 Pod 跨节点通信。
- 使用 Deployment 管理 Nginx，验证副本扩容和 Pod 故障自愈。
- 使用 NodePort 暴露服务，并通过 Endpoint、kube-proxy、nftables 定位访问故障。
- 使用 Metrics Server、node-exporter、kube-state-metrics、Prometheus 和 Grafana 构建监控链路。
- 记录镜像离线导入、CoreDNS、PVC、证书、代理和 NodePort 等真实故障的排查过程。
- 使用 Helm 管理增强版 Nginx 部署，加入 Readiness/Liveness 探针、资源限制和跨节点分布策略。
- 使用 GitHub Actions 构建并推送 GHCR 镜像，保留手动 Helm 发布和回滚入口。
- 提供 PrometheusRule 告警样例和 Pod 自愈、错误镜像、NodePort 故障演练手册。

## 架构

```mermaid
flowchart LR
    U[客户端 / curl] --> S[NodePort Service]
    S --> P1[nginx-demo Pod]
    S --> P2[nginx-demo Pod]
    P1 --> W[k8s-worker]
    P2 --> C[k8s-master]

    M[Metrics Server] --> K[Kubernetes API]
    N[node-exporter] --> PR[Prometheus]
    KS[kube-state-metrics] --> PR
    PR --> G[Grafana]
```

## 目录

```text
docs/
├── 架构说明.md                              架构与请求/监控链路
├── 项目摘要.md                              简历与面试项目说明
├── 完整部署过程.md                          从双节点集群到监控的复现步骤
├── 通用排障.md                              通用排障手册
├── Kubernetes 云原生实验集群排障记录.md    按时间记录的完整实验排障过程
├── 企业化增强实施说明.md                    Helm、CI/CD、探针和回滚说明
├── 故障演练手册.md                          可重复的故障注入与恢复步骤
└── incidents/                              按具体问题归档的故障复盘
k8s/app/                                    基础 Nginx Deployment 与 NodePort Service
deploy/helm/nginx-demo/                     增强版 Helm Chart
monitoring/                                 PromQL 和告警规则
Dockerfile + site/                          自定义 Nginx 镜像
.github/workflows/build-image.yml           GitHub Actions 构建流水线
```

## 快速验证

```bash
kubectl apply -f k8s/app/nginx-demo-deployment.yaml
kubectl apply -f k8s/app/nginx-demo-service.yaml
kubectl get pods -l app=nginx-demo -o wide
kubectl get endpoints nginx-demo-svc
kubectl get svc nginx-demo-svc
```

NodePort 端口以 `kubectl get svc` 的实际输出为准。实验中曾使用 `31258`，不同集群可能分配不同端口。

完整部署步骤见 [`docs/完整部署过程.md`](docs/%E5%AE%8C%E6%95%B4%E9%83%A8%E7%BD%B2%E8%BF%87%E7%A8%8B.md)。

企业化增强步骤见 [`docs/企业化增强实施说明.md`](docs/%E4%BC%81%E4%B8%9A%E5%8C%96%E5%A2%9E%E5%BC%BA%E5%AE%9E%E6%96%BD%E8%AF%B4%E6%98%8E.md)。

## 监控验证

```bash
kubectl top nodes
kubectl top pods -A
```

在 Prometheus 的 Targets 页面确认采集目标为 `UP`，在 Grafana 中配置 Prometheus 数据源后导入或创建 Dashboard。常用查询见 [`monitoring/promql-examples.md`](monitoring/promql-examples.md)。

## 故障排查方法

遇到问题时遵循：

```text
状态 → 节点 → Events → 日志 → Service/Endpoint → 节点网络 → kubelet/containerd/kube-proxy → 修复 → 验证
```

完整案例见 [`docs/通用排障.md`](docs/%E9%80%9A%E7%94%A8%E6%8E%92%E9%9A%9C.md)、[`docs/Kubernetes 云原生实验集群排障记录.md`](docs/Kubernetes%20云原生实验集群排障记录.md) 和 [`docs/incidents/`](docs/incidents/)。

## 安全说明

仓库不包含 kubeconfig、SSH 私钥、密码、Token、镜像 tar 包、Prometheus 数据目录或真实敏感日志。节点 IP、用户名和镜像版本应按公开仓库需要进行脱敏或替换。

## 项目状态

当前实验已完成 Kubernetes 应用部署、NodePort、扩容、自愈和 Prometheus/Grafana 基础监控，并已补充 Helm、健康检查、镜像构建流水线、告警样例和故障演练。后续可继续补充持久化存储、真正的自动部署环境和多控制平面高可用。
