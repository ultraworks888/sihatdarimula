import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react-swc";
import tailwindcss from "@tailwindcss/vite";
import path from "path";
import { viteErrorReporter } from 'vite-error-reporter';
import { execSync } from 'child_process'
import sgPreviewPlugin from 'sg-preview-plugin';

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  // NOTE: siteName should be something like: vitesite-4.sg-host.com
  const siteName = execSync("/usr/local/bin/sg-site main").toString().trim();

  // Set the environment variable
  process.env.VITE_POCKETBASE_URL = `https://${siteName}`;

  return {
    server: {
      allowedHosts: [
        '.coderick.ai',
        '.coderick.net',
        '.local.sgvps.net',
        '.sg-host.com',
        '.staging.vibe-platform.net',
        '.vibe-platform.net',
      ],
      cors: true,
    },
    plugins: [
      react(),
      tailwindcss(),

      ...(mode === 'development' ? [viteErrorReporter({
        enableConsoleLogging: false,
        enableDebugLogging: false,
      }), sgPreviewPlugin()] : []),
    ],
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "./src"),
      },
    },
  };
});
