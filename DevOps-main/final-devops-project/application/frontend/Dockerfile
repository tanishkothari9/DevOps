ARG NGINX_IMAGE=nginxinc/nginx-unprivileged:1.30-alpine

# ---- build stage: Node compiles the React app into static files ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build

# ---- runtime stage: unprivileged nginx serves dist/ (no Node, no npm in the final image) ----
FROM ${NGINX_IMAGE}
LABEL org.opencontainers.image.source="https://github.com/tanishkothari9/DevOps" \
      org.opencontainers.image.title="stockpilot-frontend"
ENV BACKEND_URL=http://backend:8000
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
USER 101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
