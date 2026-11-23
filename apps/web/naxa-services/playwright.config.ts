import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 30_000,
  expect: { timeout: 8_000 },
  fullyParallel: false,
  workers: 1,
  reporter: "line",
  use: {
    baseURL: "http://127.0.0.1:4173",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  webServer: [
    {
      command: "npm run dev --workspace @famille/naxa-services-web -- --host 127.0.0.1 --port 4173 --strictPort",
      url: "http://127.0.0.1:4173",
      reuseExistingServer: !process.env.CI,
      timeout: 30_000,
      env: {
        VITE_NAXA_SERVICES_AUTH_URL: "https://naxa-services-e2e.invalid/functions/v1/naxa-services-auth",
        VITE_SUPABASE_ANON_KEY: "naxa-services-e2e-public-anon-key-not-a-secret",
      },
    },
    {
      command: "npm run build --workspace @famille/naxa-services-web && npm run preview --workspace @famille/naxa-services-web -- --host 127.0.0.1 --port 4174 --strictPort",
      url: "http://127.0.0.1:4174",
      reuseExistingServer: !process.env.CI,
      timeout: 60_000,
      env: {
        VITE_NAXA_SERVICES_AUTH_URL: "https://naxa-services-e2e.invalid/functions/v1/naxa-services-auth",
        VITE_SUPABASE_ANON_KEY: "naxa-services-e2e-public-anon-key-not-a-secret",
      },
    },
  ],
});
