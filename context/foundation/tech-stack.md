---
starter_id: 10x-astro-starter
package_manager: npm
project_name: t-sql-doradca
hints:
  language_family: js
  team_size: solo
  deployment_target: cloudflare-workers
  ci_provider: github-actions
  ci_default_flow: auto-deploy-on-merge
  bootstrapper_confidence: first-class
  path_taken: standard
  quality_override: false
  self_check_answers: null
  has_auth: true
  has_payments: false
  has_realtime: false
  has_ai: false
  has_background_jobs: false
---

## Why this stack

T-SQL Doradca is a small, single-team web app with a one-week after-hours MVP budget that needs invite-only login, a durable shared history of analyses, and owner-based record-level authorization. The 10x Astro Starter is the recommended default for a JS/TS web app and delivers exactly that out of the box: Supabase auth plus PostgreSQL with row-level security maps directly onto the owner-only modify/delete rules, TypeScript with Zod schemas gives explicit contracts, and it clears all four agent-friendly quality gates. The static T-SQL rule engine is pure TypeScript running in request handlers, so the edge runtime's limits on long-running work do not bite. Deployment targets Cloudflare Workers, which the starter runs on natively; CI is GitHub Actions with auto-deploy on merge to the `master` branch. Public sign-up must be disabled in Supabase so accounts are created only by invitation, as the PRD requires. Payments, realtime, AI and background jobs are out of scope.
