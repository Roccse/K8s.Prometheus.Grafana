# CoreDNS 镜像拉取故障复盘

## 现象

Worker 上 CoreDNS 进入 `ErrImagePull` / `ImagePullBackOff`，而 Master 上 CoreDNS 正常。

## 定位

```bash
kubectl describe pod -n kube-system <worker-coredns-pod>
```

事件显示 Worker 连接镜像仓库时被拒绝。镜像引用本身是正确的，问题属于节点出口网络，而不是 CoreDNS 配置。

## 修复

确认 Master 本地存在同名镜像后执行离线导入：

```bash
sudo ctr -n k8s.io images list | grep coredns
sudo ctr -n k8s.io images export /tmp/coredns.tar <exact-image-reference>
scp /tmp/coredns.tar <worker-user>@<worker-ip>:/tmp/
sudo ctr -n k8s.io images import /tmp/coredns.tar
```

删除失败 Pod 由 Deployment 自动重建，并观察两个 CoreDNS Pod 均为 `1/1 Running`。
