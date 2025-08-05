# Dockerfile optimisé pour Angular
FROM node:18-alpine as build

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build --prod

# Stage de production avec NGINX
FROM nginx:alpine

# Copier les fichiers buildés
COPY --from=build /app/dist/* /usr/share/nginx/html/

# Configuration NGINX pour SPA
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 4200;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Support pour Single Page Application
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Headers de sécurité
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF

EXPOSE 4200
CMD ["nginx", "-g", "daemon off;"]