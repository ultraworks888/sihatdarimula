import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react-swc";
import tailwindcss from "@tailwindcss/vite";
import path from "path";
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const SITEGROUND_CLI = "/usr/local/bin/sg-site";
const SITEGROUND_MODULE_ROOT = "/usr/lib/node_modules_22";
const require = createRequire(import.meta.url);

function configurePocketBaseUrl(mode: string, env: Record<string, string>) {
  const explicitUrl =
    process.env.VITE_POCKETBASE_URL?.trim() ||
    env.VITE_POCKETBASE_URL?.trim();

  if (explicitUrl) {
    process.env.VITE_POCKETBASE_URL = explicitUrl;
    return;
  }

  if (existsSync(SITEGROUND_CLI)) {
    const siteName = execFileSync(SITEGROUND_CLI, ["main"], {
      encoding: "utf8",
    }).trim();

    if (!siteName) {
      throw new Error(
        "[vite] SiteGround hostname discovery returned an empty value. Set VITE_POCKETBASE_URL explicitly.",
      );
    }

    process.env.VITE_POCKETBASE_URL = `https://${siteName}`;
    return;
  }

  if (mode === "development") {
    process.env.VITE_POCKETBASE_URL = "http://127.0.0.1:8090";
    return;
  }

  throw new Error(
    "[vite] VITE_POCKETBASE_URL is required for non-development builds outside SiteGround/Coderick. Set it in the build environment.",
  );
}

async function loadSiteGroundDevelopmentPlugins() {
  if (!existsSync(SITEGROUND_CLI)) {
    return [];
  }

  const reporterPackage = path.join(
    SITEGROUND_MODULE_ROOT,
    "vite-error-reporter",
  );
  const previewPackage = path.join(
    SITEGROUND_MODULE_ROOT,
    "sg-preview-plugin",
  );

  if (!existsSync(reporterPackage) || !existsSync(previewPackage)) {
    return [];
  }

  const reporterEntry = require.resolve(reporterPackage);
  const previewEntry = require.resolve(previewPackage);
  const [reporterModule, previewModule] = await Promise.all([
    import(pathToFileURL(reporterEntry).href),
    import(pathToFileURL(previewEntry).href),
  ]);

  if (
    typeof reporterModule.viteErrorReporter !== "function" ||
    typeof previewModule.default !== "function"
  ) {
    throw new Error(
      "[vite] SiteGround development plugins have an incompatible module shape.",
    );
  }

  return [
    reporterModule.viteErrorReporter({
      enableConsoleLogging: false,
      enableDebugLogging: false,
    }),
    previewModule.default(),
  ];
}

// https://vite.dev/config/
export default defineConfig(async ({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  configurePocketBaseUrl(mode, env);
  const siteGroundPlugins =
    mode === "development" ? await loadSiteGroundDevelopmentPlugins() : [];

  return {
    server: {
      allowedHosts: [
        ".coderick.ai",
        ".coderick.net",
        ".local.sgvps.net",
        ".sg-host.com",
        ".staging.vibe-platform.net",
        ".vibe-platform.net",
      ],
      cors: true,
    },
    plugins: [
      react(),
      tailwindcss(),
      ...siteGroundPlugins,
    ],
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "./src"),
      },
    },
  };
});
