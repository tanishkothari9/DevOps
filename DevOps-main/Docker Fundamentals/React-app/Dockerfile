# ---- Stage 1: Build the React app ----
FROM node:20-alpine AS build

WORKDIR /app

# Install dependencies
COPY package.json ./
RUN npm install

# Copy source and build the production bundle
COPY public ./public
COPY src ./src
RUN npm run build

# ---- Stage 2: Serve the build with Nginx ----
FROM nginx:alpine

# Copy the built static files into Nginx's web root
COPY --from=build /app/build /usr/share/nginx/html

EXPOSE 80
