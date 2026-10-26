# syntax=docker/dockerfile:1
# @static-doc
# 作用：官网生产镜像：nginx alpine 运行静态页面，单 worker、非 root、8080 端口，面向低内存自托管与 Cloudflare Tunnel。
#
# ## 契约与约束
# - 构建上下文是 `website/`，只复制运行时需要的页面、`assets/` 与 nginx 配置；工具、README 与 MANIFEST 不进入镜像。
# - nginx 以非 root `nginx` 用户运行，配置固定监听 8080；必须与 `deploy/nginx.conf` 的 pid / temp 路径一致。
# - 容器只读运行：运行期只写 `/tmp`；日志走 stdout/stderr。
# - 镜像不包含游戏本体、构建工具或 Node 运行时，体积与内存占用保持在静态站级别。
#
# ## 重点逻辑
# ### 低内存
# - `worker_processes 1` + 精简 nginx.conf；单个静态站不需要多 worker。
# - 使用 `nginx:1.27-alpine` 作为运行时基座，避免额外 OS 层。
# ### 健康检查
# - `/healthz` 由 nginx 直接返回 200，供 Docker / Compose / CI 等待就绪。
# @end-static-doc

FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="Steam Navigator Website"
LABEL org.opencontainers.image.description="Static official site for Steam Navigator"
LABEL org.opencontainers.image.source="https://github.com/xs-www/SteamNavigator"

RUN rm -f /etc/nginx/conf.d/default.conf

COPY deploy/nginx.conf /etc/nginx/nginx.conf
COPY index.html game.html wiki.html devlog.html download.html team.html favicon.svg /usr/share/nginx/html/
COPY assets/css/ /usr/share/nginx/html/assets/css/
COPY assets/js/ /usr/share/nginx/html/assets/js/
COPY assets/data/ /usr/share/nginx/html/assets/data/
COPY assets/img/ /usr/share/nginx/html/assets/img/

# MANIFEST 只用于仓库内追溯，不对外提供。
RUN rm -f /usr/share/nginx/html/assets/img/MANIFEST.md \
    && chown -R nginx:nginx /usr/share/nginx/html

USER nginx

EXPOSE 8080
STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["nginx", "-g", "daemon off;"]
