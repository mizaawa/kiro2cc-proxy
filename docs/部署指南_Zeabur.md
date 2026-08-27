# Zeabur 部署指南

## 构建方式

使用 GitHub 仓库源码部署，由 Zeabur 根据仓库根目录的 Dockerfile 构建镜像，不使用 GHCR 预构建镜像。

## 部署步骤

> 在 Zeabur 选择 Git 仓库部署，并连接 `mizaawa/kiro2cc-proxy`。Dockerfile 默认使用单任务 Cargo 编译和低内存 Docker profile。

### 1. 创建服务

Add Service → Git → 选择 `mizaawa/kiro2cc-proxy` → 使用根目录 Dockerfile

### 2. 挂载持久化卷

- Mount Directory：`/app/config`
- 作用：保存凭据数据，防止重启丢失
- **注意**：`credentials.json` 不要添加到 Config File，应用需要运行时写入该文件

### 3. 添加配置文件

在 Config File 中添加 `/app/config/config.json`，内容如下：

```json
{
  "host": "0.0.0.0",
  "port": 5678,
  "adminPsw": "你的管理后台密钥"
}
```

### 4. 开放网络端口

在 Networking 中开放端口 `5678`

### 不需要配置的项

- **环境变量** — Config File 已提供配置，无需设置
- **启动命令（Command）** — 镜像内置，无需填写
- **Dockerfile** — 使用仓库根目录的 Dockerfile

## 常见问题

### 凭据重启后丢失

确保 `credentials.json` **没有**被添加到 Config File 中。Zeabur 的 Config File 会以只读方式挂载，覆盖持久化卷上的同名文件，导致应用无法写入凭据数据。详见 [排查记录](troubleshooting/排障指南_Zeabur只读挂载问题.md)。

### 构建内存不足

确认部署使用仓库最新 Dockerfile。默认 `CARGO_BUILD_JOBS=1`，并关闭 Docker 构建中的 LTO，以降低 Rust 编译峰值内存。
