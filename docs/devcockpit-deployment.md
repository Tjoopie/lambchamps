# DevCockpit Deployment Runbook (Lambchamps)

## App Target
- App ID: `app_wxppx6-6v5Wb`
- Tenant ID: `prod`
- Environment target: `production` at `https://devcockpit.ai`
- Primary hosted URL: `https://devcockpit.ai/apps/app_wxppx6-6v5Wb/`
- Subdomain URL: `https://app_wxppx6-6v5Wb.devcockpit.ai/`
- Default path-hosted base: `/apps/app_wxppx6-6v5Wb/`

## Canonical Docs
- Environment deployment guide: `docs/current-deployment/PRODUCTION_DEPLOYMENT_GUIDE.md`
- Frontend build guide: `docs/guides/BUILDING_FRONTEND_APPS.md`
- Handoff runbook: `docs/runbooks/external-app-handoff-runbook.md`

## Deployment Flow
1. Call `dc__deploy_app` before each deploy so you use the live upload instructions for this exact app/environment.
2. Build the frontend artifact (for example `npm run build`).
3. Package the build from inside the output directory so `index.html` is at the archive root.
4. Deploy to sandbox (default): upload without target or with `target=sandbox`. Test at `https://sandbox.devcockpit.ai/apps/<app_id>/`.
5. When ready for farmers/users: call `dc__promote_app` to create a pending promotion, have the developer review the sandbox URL, then call `dc__confirm_promotion` with the promotion_id.
6. After deploy, hard refresh once so the injected `env-config.js` is reloaded before debugging auth or runtime issues.

## Packaging Commands
1. macOS/Linux: `cd dist && zip -r ../build.zip . && cd ..`
2. Windows PowerShell: `tar.exe -a -cf build.zip -C dist .`

## Important Notes
- Deploys go to SANDBOX by default. Farmers never see sandbox deploys until you call `dc__confirm_promotion` after human review.
- Direct production deploy: pass `target=production` to the upload endpoint or `dc__deploy_app({ target: "production" })` only when intentionally skipping sandbox.
- Sandbox URL: `https://sandbox.devcockpit.ai/apps/app_wxppx6-6v5Wb/`
- Production URL: `https://devcockpit.ai/apps/app_wxppx6-6v5Wb/`
- Production traffic uses `https://devcockpit.ai/apps/app_wxppx6-6v5Wb/` after promotion.
- If you build for the default DevCockpit path host, set `base: '/apps/app_wxppx6-6v5Wb/'` in Vite so asset paths resolve under the hosted route.
- For client-side routers such as React Router BrowserRouter, read `window.__DEVCOCKPIT__.APP_BASE_PATH` and use it as the router basename (default `/apps/app_wxppx6-6v5Wb`).
- Use `dc__deploy_app` as the canonical deploy path instead of relying on stale historical curl commands.
- Zip from inside the build output directory so `index.html` is at the archive root.
- After any deploy that changes hosted config, Firebase config, or hosted self-signup, hard refresh once so `window.__DEVCOCKPIT__` is fresh.
- Hosted deploys auto-inject a runtime error overlay so uncaught errors render visibly instead of failing to a blank screen.
- window.__DEVCOCKPIT__.ENVIRONMENT is `sandbox` or `production` based on deploy target — use it to show a sandbox banner.
- Direct upload endpoint reference: `https://devcockpit.ai/api/apps/app_wxppx6-6v5Wb/deploy` (requires an `ak_*` App API key, not the MCP token).
- Packaging rule: Zip must contain index.html at root. Create zip from INSIDE the build output directory (cd dist && zip -r ../build.zip .). On Windows use tar.exe -a -cf.
- Multi-route support: Next.js app-router static exports with per-route index.html files (e.g. admin/index.html, dashboard/index.html) are fully supported. All index.html files get asset path rewriting, env-config.js injection, and the hosted runtime error guard.
- env-config.js: env-config.js is auto-injected on deploy. All values are available at runtime via window.__DEVCOCKPIT__, including APP_BASE_PATH for router basename and DEPLOY_VERSION for cache-busting diagnostics.

## Post-Deploy Verification
1. Open `https://devcockpit.ai/apps/app_wxppx6-6v5Wb/`.
2. Confirm the default hosted URL serves the new build.
3. Hard refresh once to pick up the injected `env-config.js`.
4. Verify `window.__DEVCOCKPIT__` contains `API_BASE_URL`, `APP_ID`, `TENANT_ID`, and any Firebase or hosted-signup fields your app expects.