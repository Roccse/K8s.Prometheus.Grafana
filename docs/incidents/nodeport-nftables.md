# NodePort 与 nftables 故障复盘

## 现象

Master 一度无法通过 `127.0.0.1:31258` 访问 `nginx-demo`，而 Worker 可以访问。初次执行 `iptables-save` 没有看到 `31258`。

## 排查

```bash
kubectl get svc nginx-demo-svc
kubectl get endpoints nginx-demo-svc
kubectl get endpointslice -l kubernetes.io/service-name=nginx-demo-svc
kubectl port-forward service/nginx-demo-svc 8080:80
```

端口转发可以返回 Nginx，证明 Pod、Service 和 Endpoint 正常。随后分别测试 Worker、Master、本机回环和节点 IP，并检查 kube-proxy 日志与规则。

## 关键发现

Master 使用 `iptables-nft` / `nf_tables` 后端，legacy 表中没有 Kubernetes 规则。使用以下命令确认真实规则：

```bash
sudo nft list ruleset
```

最终确认流量链路为：

```text
tcp dport 31258 → KUBE-EXT → KUBE-SVC → Pod Endpoint
```

## 验证

```text
Master localhost → NodePort：成功
Master IP → NodePort：成功
Worker → Master NodePort：成功
Worker → Worker NodePort：成功
```

## 经验

不要仅凭某一套 `iptables-save` 输出判断 kube-proxy 是否失效。先确认系统实际使用的 netfilter 后端，再用 `nft list ruleset`、Service Endpoint 和实际请求结果交叉验证。不要手工维护 kube-proxy 规则。
