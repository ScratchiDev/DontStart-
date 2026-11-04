import { defineConfig } from 'vite';

// Le site est servi sur https://d4w647nmnx-hub.github.io/Claude-/ par GitHub Pages,
// d'où la base. En local (npm run dev) Vite gère ce préfixe tout seul.
export default defineConfig({
  base: '/Claude-/',
  build: {
    target: 'es2020',
    chunkSizeWarningLimit: 1500,
  },
  server: { port: 5173 },
});
