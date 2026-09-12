# Kubernetes 云原生实验集群排障记录

## 一、实验环境

```
控制平面：k8s-master
IP：192.168.121.10

工作节点：k8s-worker
IP：192.168.121.11

Kubernetes：v1.30.14
容器运行时：containerd
CNI：Flannel
```

------

## 二、静态 IP 被 DHCP 覆盖

### 故障现象

Master 原本配置了静态 IP，但虚拟机重启后 IP 发生变化。**临时修改 IP 不能持久化，必须修改 Netplan 配置。**

### 根因

Netplan 配置中：

```
dhcp4: true
```

**DHCP 仍然开启**，导致静态地址没有真正生效。

### 排查和修复

**检查 IP：**

```
ip addr
ip route		 # 查看路由表，确认默认网关和网络转发路径
```

**检查 Netplan：**

```
sudo cat /etc/netplan/*.yaml
```

**Master 配置：**

```
dhcp4: false
addresses:
  - 192.168.121.10/24
```

**Worker 配置：**

```
dhcp4: false
addresses:
  - 192.168.121.11/24
```

**应用配置：**

```
sudo netplan apply
ip addr
```

------

## 三、Worker 的 Role 显示为 `<none>`

### 故障现象

```
k8s-worker   Ready   <none>
```

### 原因

Worker 默认没有角色标签。`<none>` 不代表节点故障，也不影响调度。

### 验证节点状态

```
kubectl get nodes
kubectl describe node k8s-worker
```

注意，`describe` 不是独立命令，必须写成：

```
kubectl describe node k8s-worker
```

**查看污点（确认节点是否对 Pod 调度有限制）：**

```
kubectl get node k8s-worker \
  -o jsonpath='{.spec.taints}'; echo		# .spec.taints 用于读取节点污点
```

------

## 四、Flannel 崩溃导致 Pod 无法创建

### 故障现象

Nginx Pod 一直处于：

```
ContainerCreating
```

事件中出现：

```
failed to load flannel subnet.env
/run/flannel/subnet.env: no such file or directory
```

同时 Worker 上 Flannel 处于：

```
CrashLoopBackOff		# Flannel Pod 容器反复崩溃并重启
```

### 排查命令

**以下命令在 Master 上执行：**

```
kubectl get pods -A -o wide		# -A 查看所有命名空间的 Pod；-o wide 显示节点、IP 等详细信息
kubectl logs -n kube-flannel <Worker上的Flannel Pod> --previous		# -n 指定命名空间；--previous 查看上一个已退出容器的日志
kubectl describe pod -n kube-flannel <Worker上的Flannel Pod>
```

### 进一步发现

Worker 无法从 `registry.k8s.io` 拉取 kube-proxy 镜像；在本次实验中，kube-proxy 异常与 Flannel 网络故障同时出现。补齐镜像并恢复相关组件后，Flannel 成功运行。这里记录的是本次环境观察到的依赖关系，不应概括为“kube-proxy 镜像拉取失败必然导致 Flannel 崩溃”。

### 处理方式

**在 Master 导出已有镜像：**

```
sudo ctr -n k8s.io images export \
  /tmp/kube-proxy-v1.30.14.tar \
  registry.k8s.io/kube-proxy:v1.30.14
```

**复制到 Worker（`scp` 只负责传输镜像归档文件）：**

```
scp /tmp/kube-proxy-v1.30.14.tar \
  ubuntu-user@192.168.121.11:/tmp/
```

**在 Worker 导入镜像：**

```
sudo ctr -n k8s.io images import \
  /tmp/kube-proxy-v1.30.14.tar
```

**在 Worker 重启 kubelet：**

```
sudo systemctl restart kubelet
```

**回到 Master，重启相关 Pod：**

```
kubectl delete pod -n kube-system \
  -l k8s-app=kube-proxy

kubectl delete pod -n kube-flannel \
  -l app=flannel
```

### 验证结果

```
kubectl get pods -A -o wide
```

Flannel 和 kube-proxy 最终均恢复为：

```
1/1 Running
```

------

## 五、CoreDNS 镜像拉取失败

### 故障现象

CoreDNS 在 Worker 上：

```
ErrImagePull
ImagePullBackOff
```

事件显示无法访问：

```
registry.k8s.io/coredns/coredns:v1.11.3
```

### 根因

Worker 到外部镜像仓库的连接被拒绝，并不是 CoreDNS 镜像名称错误。

### 处理方式

**在 Master 确认本地镜像：**

```
sudo ctr -n k8s.io images list | grep coredns
```

**在 Master 导出：**

```
sudo ctr -n k8s.io images export \
  /tmp/coredns-v1.11.3.tar \
  registry.k8s.io/coredns/coredns:v1.11.3
```

**在 Master 传输到 Worker：**

```
scp /tmp/coredns-v1.11.3.tar \
  ubuntu-user@192.168.121.11:/tmp/
```

**在 Worker 导入镜像：**

```
sudo ctr -n k8s.io images import \
  /tmp/coredns-v1.11.3.tar
```

**回到 Master，删除失败 Pod：**

```
kubectl delete pod -n kube-system <失败的CoreDNS Pod>
```

------

## 六、nginx-demo 镜像拉取失败

### 故障现象

```
nginx-demo   ImagePullBackOff
```

### 根因

Deployment 使用：

```
nginx:alpine
```

但 Master 本地只有：

```
nginx:latest
```

Worker 也无法访问 Docker Hub。

### 处理方式

将 Deployment 改为 Master 上已验证存在的镜像：

```
kubectl set image deployment/nginx-demo \
  '*=nginx:latest'
```

**在 Master 导出：**

```
sudo ctr -n k8s.io images export \
  /tmp/nginx-latest.tar \
  docker.io/library/nginx:latest
```

**在 Master 传输到 Worker：**

```
scp /tmp/nginx-latest.tar \
  ubuntu-user@192.168.121.11:/tmp/
```

**在 Worker 导入：**

```
sudo ctr -n k8s.io images import \
  /tmp/nginx-latest.tar
```

**回到 Master，重新发布：**

```
kubectl rollout restart deployment/nginx-demo
kubectl rollout status deployment/nginx-demo
```

### 验证

**在 Master 上查看：**

```
kubectl get pods -o wide
```

最终：

```
nginx-demo   1/1   Running   k8s-worker
```

------

## 七、NodePort 访问失败

### 故障现象

Master 访问：

```
curl http://127.0.0.1:31258
```

连接被拒绝，但 Worker 可以访问。

### 排查顺序

**确认 Service：**

```
kubectl get svc nginx-demo-svc
```

**确认 Endpoint：**
（Endpoint 位于 Service 和 Pod 之间，记录具体后端地址，告诉 Service 转发到哪里。）

```
kubectl get endpoints nginx-demo-svc
```

**确认 Pod：**

```
kubectl get pods -l app=nginx-demo -o wide
```

**绕过 NodePort，使用端口转发：**

```
kubectl port-forward service/nginx-demo-svc 8080:80
```

**另一个终端执行：**

```
curl http://127.0.0.1:8080
```

端口转发成功后，说明 **Pod、Service 和 Endpoint 基本正常**，问题集中在 NodePort。

### 关键发现

Master 默认使用的是：

```
iptables-nft / nf_tables
```

而不是 legacy 后端。初次使用：

```
iptables-save
iptables-legacy-save
```

没有看到规则，容易误判 kube-proxy 没有工作。**查询不到规则时，先确认实际使用的规则后端。**

**最终通过 nftables 确认：**

```
sudo nft list ruleset
```

`iptables-save` 没有输出不等于没有规则，必须先确认当前系统使用的是 legacy、iptables-nft 还是原生 nftables 后端。

确认真实规则链：

```
tcp dport 31258
  → KUBE-EXT
  → KUBE-SVC
  → Pod Endpoint
```

### 最终验证

```
Master localhost → NodePort：成功
Master IP → NodePort：成功
Worker → Master NodePort：成功
Worker → Worker NodePort：成功
```

### 结论

- kube-proxy 正常；
- NodePort 正常；
- Service 和 Endpoint 正常；
- nftables 规则正常；
- 不需要重建 Service；
- 不需要手动添加 iptables 规则；
- 不需要切换 legacy/nft 后端。

------

## 八、Metrics Server 证书错误

### 故障现象

Metrics Server 日志：

```
x509: cannot validate certificate
doesn't contain any IP SANs
```

### 根因

实验环境中的 kubelet serving certificate 没有节点 IP SAN。

### 处理方式

给 Metrics Server 增加以下参数：

```
--kubelet-insecure-tls		# 跳过 kubelet 证书校验；仅适用于实验环境
```

### 验证

```
kubectl top nodes
kubectl top pods -A
```

------

## 九、Prometheus PVC Pending

### 故障现象

```
pod has unbound immediate PersistentVolumeClaims
```

### 根因

集群没有可用的 StorageClass，Prometheus 和 Alertmanager 默认申请 PVC。

### 实验环境处理

**实验环境先关闭持久化：**

```
server.persistentVolume.enabled=false
alertmanager.persistence.enabled=false
```

### 后续生产化改进

后续应补充：

```
StorageClass
PersistentVolume
PersistentVolumeClaim
```

然后恢复 Prometheus 和 Grafana 持久化。

------

## 十、镜像、Helm 和代理问题

### 镜像拉取失败

典型错误：

```
unexpected EOF
connection reset by peer
short read
```

处理思路：

```
确认镜像名称
确认节点网络
确认代理
手动 crictl pull
删除失败 Pod 重新创建
```

### Helm 仓库超时

处理方式：

```
curl -C - 断点续传
使用 Windows Clash 代理
优先使用 OCI 镜像仓库
```

### containerd 不继承 shell 代理

即使 shell 中的 `curl` 能访问外网，containerd 仍可能拉不到镜像，因为 containerd 是 systemd 服务。

需要给 containerd 这个 systemd 服务配置：

```
HTTP_PROXY
HTTPS_PROXY
NO_PROXY
```

然后重新加载并重启服务：

```
sudo systemctl daemon-reload
sudo systemctl restart containerd
```

------

## 十一、当前项目的排障方法总结

**排查顺序：**

```
    1. 看资源状态
2. 看 Pod 所在节点
3. 看 describe 的 Events
4. 看容器日志
5. 看 Service 和 Endpoint
6. 看节点网络和端口
7. 看 kubelet、containerd、kube-proxy
8. 修改配置
9. 重建受影响资源
10. 重新验证
```

**常用命令：**

```
kubectl get pods -A -o wide
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl get svc
kubectl get endpoints
kubectl get events --sort-by=.lastTimestamp
kubectl get nodes
kubectl describe node <node-name>
```
