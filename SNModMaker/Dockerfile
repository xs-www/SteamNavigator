# SNModMaker 容器镜像（零依赖：只用 Node 内置模块）
#
# 构建上下文是 SNModMaker/ 本身，见 .dockerignore：
#   docker build -t snmodmaker:local SNModMaker
# 或从仓库根：docker compose up -d --build
FROM node:22-alpine

WORKDIR /app
COPY . /app/SNModMaker

# 容器内必须监听 0.0.0.0 才能被宿主机端口映射访问；宿主机只发布到 127.0.0.1，
# 远程访问交给 tailscale serve。所有可写目录都重定向到 /app/data（命名卷）。
ENV SNMODMAKER_HOST=0.0.0.0 \
    PORT=8099 \
    SNMODMAKER_MODS_DIR=/app/data/mods \
    SNMODMAKER_EXPORTS_DIR=/app/data/exports \
    SNMODMAKER_GAME_MODS_DIR=/app/data/game-mods \
    SNMODMAKER_WORKSPACE_ROOT=/app/data/workspace

RUN mkdir -p /app/data/mods /app/data/exports /app/data/game-mods /app/data/workspace \
    && chown -R node:node /app/data

USER node
EXPOSE 8099
CMD ["node", "/app/SNModMaker/tools/serve.mjs"]
