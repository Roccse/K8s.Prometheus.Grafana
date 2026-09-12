# Flannel 与镜像拉取故障复盘

## 现象

Worker 上 Flannel 进入 `CrashLoopBackOff`，业务 Pod 长时间处于 `ContainerCreating`。事件中出现 `subnet.env` 不存在；Worker 的 kube-proxy 同时出现 `ImagePullBackOff`。

## 定位

```bash
kubectl get pods -A -o wide
kubectl describe pod -n kube-flannel <worker-flannel-pod>
kubectl logs -n kube-flannel <worker-flannel-pod> --previous
kubectl describe pod -n kube-system <worker-kube-proxy-pod>
```

证据表明 Worker 无法访问 `registry.k8s.io`，kube-proxy 镜像未能拉取，进而影响 Flannel 访问 API Server 和生成 Pod 网络配置。

## 修复

在已有镜像的节点导出镜像，通过 SSH 复制到 Worker，再导入 Worker 的 containerd `k8s.io` 命名空间：

```bash
sudo ctr -n k8s.io images export /tmp/image.tar <image-reference>
scp /tmp/image.tar <worker-user>@<worker-ip>:/tmp/
sudo ctr -n k8s.io images import /tmp/image.tar
```

随后重启 kubelet 或删除失败 Pod，使控制器重新创建。

## 验证

```bash
kubectl get pods -A -o wide
```

Flannel、kube-proxy 和业务 Pod 均恢复为 `Running`。
