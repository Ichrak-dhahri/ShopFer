# Étape 1: Build de l'application Angular SSR
FROM node:18-alpine AS build

WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer toutes les dépendances (dev incluses pour le build)
RUN npm ci

# Copier le code source
COPY . .

# Builder l'application (Angular 18 gère SSR automatiquement)
RUN npm run build

# Debug: vérifier la structure générée
RUN ls -la /app/front/
RUN ls -la /app/front/shopfer/

# Étape 2: Runtime avec Node.js pour SSR
FROM node:18-alpine AS runtime

WORKDIR /app

# Copier les fichiers de package pour les dépendances de production
COPY package*.json ./

# Installer seulement les dépendances de production
RUN npm ci --only=production && npm cache clean --force

# Copier les fichiers buildés depuis l'étape précédente
COPY --from=build /app/front ./front

# Créer un utilisateur non-root pour la sécurité
RUN addgroup -g 1001 -S nodejs
RUN adduser -S angular -u 1001

# S'assurer que les permissions sont correctes
RUN chown -R angular:nodejs /app
USER angular

# Exposer le port
EXPOSE 4000

# Variables d'environnement
ENV NODE_ENV=production
ENV PORT=4000

# Commande pour démarrer le serveur SSR
CMD ["npm", "run", "serve:ssr:shopfer"]