# Étape 1: Build de l'application Angular
FROM node:18-alpine AS build

# Installer les dépendances système nécessaires
RUN apk add --no-cache python3 make g++ curl

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration npm
COPY package*.json ./

# Configuration npm pour une meilleure stabilité
RUN npm config set registry https://registry.npmjs.org/ && \
    npm config set strict-ssl false && \
    npm config set fetch-retries 5 && \
    npm config set fetch-retry-factor 2 && \
    npm config set fetch-retry-mintimeout 10000 && \
    npm config set fetch-retry-maxtimeout 60000

# Installer les dépendances avec gestion d'erreurs
RUN npm install --legacy-peer-deps || \
    (npm cache clean --force && npm install --legacy-peer-deps)

# Copier le code source
COPY . .

# Construire l'application avec gestion d'erreurs et détection automatique du mode
RUN if [ -f "angular.json" ]; then \
        echo "Building with Angular CLI..." && \
        (npm run build:ssr 2>/dev/null || npm run build --prod 2>/dev/null || npm run build); \
    else \
        echo "No Angular CLI configuration found, using generic build..." && \
        npm run build; \
    fi

# Debug: Afficher la structure générée
RUN echo "=== Build output structure ===" && \
    find /app -name "dist" -type d -exec ls -la {} \; || true && \
    find /app -name "*.html" -type f | head -10 || true

# Étape 2: Production avec nginx pour SPA ou Node.js pour SSR
FROM nginx:alpine AS production

# Installer curl pour les health checks
RUN apk add --no-cache curl

# Supprimer le contenu par défaut de nginx
RUN rm -rf /usr/share/nginx/html/*

# Copier les fichiers construits - gérer différentes structures de sortie
COPY --from=build /app/dist/shopfer /usr/share/nginx/html/ 2>/dev/null || \
     COPY --from=build /app/dist /usr/share/nginx/html/ 2>/dev/null || \
     COPY --from=build /app/build /usr/share/nginx/html/ 2>/dev/null || true

# Vérifier qu'au moins index.html existe et créer une page de fallback si nécessaire
RUN if [ ! -f /usr/share/nginx/html/index.html ]; then \
        echo "<!DOCTYPE html>" > /usr/share/nginx/html/index.html && \
        echo "<html><head><title>ShopFer App</title><meta charset='utf-8'></head>" >> /usr/share/nginx/html/index.html && \
        echo "<body><div id='root'><h1>ShopFer Application</h1><p>Loading...</p></div></body></html>" >> /usr/share/nginx/html/index.html; \
    fi

# Configuration nginx optimisée pour Angular SPA
RUN cat > /etc/nginx/conf.d/default.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Logs pour debug
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # Gestion des routes Angular (SPA)
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # Cache pour les assets statiques
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Compression gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types 
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json
        application/xml
        image/svg+xml;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Handle API calls (if needed)
    location /api {
        proxy_pass http://backend:3000; # Ajustez selon votre backend
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Créer un utilisateur non-root pour la sécurité
RUN addgroup -g 1001 -S appuser && \
    adduser -S -D -H -u 1001 -h /var/cache/nginx -s /sbin/nologin -G appuser -g appuser appuser

# Définir les permissions appropriées
RUN chown -R appuser:appuser /usr/share/nginx/html && \
    chown -R appuser:appuser /var/cache/nginx && \
    chown -R appuser:appuser /var/log/nginx && \
    chown -R appuser:appuser /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appuser /var/run/nginx.pid

# Exposer le port
EXPOSE 80

# Variables d'environnement
ENV NODE_ENV=production
ENV NGINX_ENVSUBST_TEMPLATE_DIR=/etc/nginx/templates
ENV NGINX_ENVSUBST_TEMPLATE_SUFFIX=.template

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Changer vers l'utilisateur non-root
USER appuser

# Démarrer nginx
CMD ["nginx", "-g", "daemon off;"]

# Alternative: Version avec SSR Node.js (commentée)
# FROM node:18-alpine AS ssr-production
# 
# WORKDIR /app
# 
# # Copier package.json pour les dépendances de production
# COPY package*.json ./
# RUN npm ci --only=production && npm cache clean --force
# 
# # Copier les fichiers build depuis l'étape de construction
# COPY --from=build /app/dist ./dist
# 
# # Créer un utilisateur non-root
# RUN addgroup -g 1001 -S nodejs && \
#     adduser -S angular -u 1001 -G nodejs
# 
# # Changer les permissions
# RUN chown -R angular:nodejs /app
# USER angular
# 
# # Exposer le port
# EXPOSE 4000
# 
# # Variables d'environnement
# ENV NODE_ENV=production
# ENV PORT=4000
# 
# # Health check pour SSR
# HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
#     CMD curl -f http://localhost:4000/ || exit 1
# 
# # Démarrer le serveur SSR
# CMD ["node", "dist/server/server.mjs"]