# 使用多阶段构建优化镜像体积
FROM node:18-alpine AS builder

# 安装构建依赖（Chromium + 系统库）
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    git

# 配置Chromium环境变量
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# 启用并配置pnpm
RUN corepack enable
RUN npm install -g corepack@latest
# 使用明确的稳定版本
RUN corepack prepare pnpm@8.15.4 --activate

WORKDIR /app

# 优先复制包管理文件
COPY package.json pnpm-lock.yaml* ./

# 安装所有依赖
RUN pnpm install --frozen-lockfile

# 复制项目文件
COPY . .

# 构建项目
RUN pnpm build

# 生产阶段
FROM node:18-alpine AS production

# 安装运行时依赖
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont

# 配置环境变量
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV NODE_ENV=production

# 启用并配置pnpm
RUN corepack enable
RUN npm install -g corepack@latest
# 使用明确的稳定版本
RUN corepack prepare pnpm@8.15.4 --activate

WORKDIR /app

# 复制包管理文件
COPY --from=builder /app/package.json .
COPY --from=builder /app/pnpm-lock.yaml .

# 仅安装生产依赖
RUN pnpm install --prod --frozen-lockfile

# 复制构建产物
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
# 如果有配置文件需要添加
COPY next.config.mjs ./
# 国际化配置
#COPY --from=builder /app/next-i18next.config.js ./

# 暴露端口
EXPOSE 3000

# 启动命令
CMD ["pnpm", "start"]