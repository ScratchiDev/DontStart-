import { defineConfig } from 'vite';

// Sur GitHub Pages, le site est servi sous /<nom-du-dépôt>/ : le workflow passe ce
// préfixe via BASE_PATH. En local (npm run dev), le jeu est servi à la racine.
export default defineConfig({
  base: process.env.BASE_PATH || '/',
  build: {
    target: 'es2020',
    chunkSizeWarningLimit: 1500,
  },
  server: { port: 5173 },
});
