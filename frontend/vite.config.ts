import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0', // Уже должно быть, но на всякий случай
    allowedHosts: true, // 👈 Разрешаем Vite обращаться к контейнеру 'web'
    proxy: {
      '/cable': {
        target: 'http://web:3000',
        ws: true,
        changeOrigin: true,
        rewriteWsOrigin: true,
      },
      '/api': {
        target: 'http://web:3000', // Ваш текущий target
        changeOrigin: true,
      },
    },
  },
})
