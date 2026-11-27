import {defineConfig} from "@playwright/test";
export default defineConfig({testDir:"./e2e",workers:1,timeout:45000,use:{baseURL:"http://127.0.0.1:4173",browserName:"chromium"},webServer:{command:"npx vite preview --host 127.0.0.1 --port 4173 --strictPort",cwd:new URL(".",import.meta.url).pathname, url:"http://127.0.0.1:4173",reuseExistingServer:false,timeout:120000}});
