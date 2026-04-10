# FastAPI 服务部署（CentOS 8）

本文对应当前项目 `main.py`，推荐生产方式：

- 应用：FastAPI (`main:app`)
- 进程守护：`systemd`
- Python WSGI/ASGI 服务器：`gunicorn + uvicorn worker`
- 反向代理：`nginx`

## 1. 你可以直接使用一键脚本

```bash
chmod +x deploy.sh
./deploy.sh
```

脚本会自动完成：

- 安装基础依赖
- 同步代码到 `/opt/llm_router`
- 创建虚拟环境并安装依赖
- 生成并启动 `systemd` 服务
- 生成并加载 `nginx` 配置
- 执行防火墙和 SELinux 常见设置

## 2. 首次执行前需要改的变量

编辑 `deploy.sh` 顶部配置：

- `APP_USER` / `APP_GROUP`：运行服务的系统用户
- `APP_DIR`：部署目录（默认 `/opt/llm_router`）
- `WORKERS`：gunicorn 进程数（建议 `CPU核数*2+1` 或先从 `2` 开始）
- `DOMAIN`：你的域名（无域名可先填服务器 IP）

也可以用环境变量覆盖，例如：

```bash
APP_DIR=/opt/llm_router DOMAIN=api.example.com WORKERS=4 ./deploy.sh
```

## 3. 模板文件位置

- `deploy/llm-router.service`：systemd 配置模板
- `deploy/nginx.llm-router.conf`：nginx 配置模板

## 4. 常用运维命令

```bash
sudo systemctl status llm-router
sudo systemctl restart llm-router
journalctl -u llm-router -f
sudo nginx -t && sudo systemctl reload nginx
```

## 5. HTTPS（建议）

建议接入证书（如 Let's Encrypt），并将 `80` 跳转到 `443`。可使用 `certbot`。

## 6. 关于 `main.py` 的说明

当前 `main.py` 中 `if __name__ == "__main__"` 使用了 `reload=True`，这是开发模式。
生产不会走这段启动逻辑，因为我们使用的是 `systemd -> gunicorn main:app`，无需改动业务接口代码即可上线。
