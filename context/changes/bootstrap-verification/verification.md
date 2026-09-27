---
bootstrapped_at: 2026-09-23T22:09:45Z
starter_id: 10x-astro-starter
starter_name: "10x Astro Starter (Astro + Supabase + Cloudflare)"
project_name: t-sql-doradca
language_family: js
package_manager: npm
cwd_strategy: git-clone
bootstrapper_confidence: first-class
phase_3_status: ok
audit_command: "npm audit --json"
---

## Hand-off

```yaml
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
```

**Why this stack**: T-SQL Doradca is a small, single-team web app with a one-week after-hours MVP budget that needs invite-only login, a durable shared history of analyses, and owner-based record-level authorization. The 10x Astro Starter is the recommended default for a JS/TS web app and delivers exactly that out of the box: Supabase auth plus PostgreSQL with row-level security maps directly onto the owner-only modify/delete rules, TypeScript with Zod schemas gives explicit contracts, and it clears all four agent-friendly quality gates. The static T-SQL rule engine is pure TypeScript running in request handlers, so the edge runtime's limits on long-running work do not bite. Deployment targets Cloudflare Workers, which the starter runs on natively; CI is GitHub Actions with auto-deploy on merge to the `master` branch. Public sign-up must be disabled in Supabase so accounts are created only by invitation, as the PRD requires. Payments, realtime, AI and background jobs are out of scope.

## Pre-scaffold verification

| Signal      | Value                                                        | Severity | Notes                                                                                           |
| ----------- | ------------------------------------------------------------ | -------- | ----------------------------------------------------------------------------------------------- |
| npm package | not run                                                      | —        | cmd_template starts with `git clone`; no npm CLI to check                                        |
| GitHub repo | przeprogramowani/10x-astro-starter last commit 2026-09-12    | fresh    | `gh` CLI not installed; date read via `git log -1` on the fresh clone (HEAD 4c0b8a0) instead of `pushed_at` |

## Scaffold log

**Resolved invocation**: `git clone https://github.com/przeprogramowani/10x-astro-starter .bootstrap-scaffold && cd .bootstrap-scaffold && npm install`
**Strategy**: git-clone
**Exit code**: 0
**Files moved**: 21 top-level entries (.env.example, .github/, .gitignore, .husky/, .nvmrc, .prettierrc.json, .vscode/, AGENTS.md, astro.config.mjs, CLAUDE.md → CLAUDE.md.scaffold, components.json, eslint.config.js, package.json, package-lock.json, public/, README.md, scripts/, src/, supabase/, tsconfig.json, wrangler.jsonc)
**Conflicts (.scaffold siblings)**: CLAUDE.md.scaffold
**.gitignore handling**: moved silently (absent in cwd)
**.bootstrap-scaffold cleanup**: deleted

Notes:
- `.bootstrap-scaffold/.git/` deleted before move-up (upstream history not carried over).
- Moving `node_modules/` from the temp dir failed on Windows (`Permission denied`, directory lock). The temp `node_modules/` was deleted with `.bootstrap-scaffold/` and dependencies were reinstalled in the project root with `npm ci` (exit 0, 648 packages) from the starter's `package-lock.json`.
- npm 12 blocked install scripts for 3 packages not covered by `allowScripts`: `esbuild@0.28.2`, `esbuild@0.28.1`, `workerd@1.20260911.1` (postinstall `node install.js`). Dev/build may require approving them (`npm install-scripts approve <pkg>`).
- Toolchain: node v24.20.0 (starter `.nvmrc` / card expects node 22), npm 12.0.2, git 2.55.0.

## Post-scaffold audit

**Tool**: npm audit --json
**Summary**: 0 CRITICAL, 0 HIGH, 0 MODERATE, 0 LOW
**Direct vs transitive**: 0/0/0/0 direct of total 0/0/0/0 (804 dependencies audited: 377 prod, 269 dev, 167 optional)

#### CRITICAL findings

none

#### HIGH findings

none

#### MODERATE findings

none

#### LOW / INFO findings

none

## Hints recorded but not acted on

| Hint                    | Value              |
| ----------------------- | ------------------ |
| bootstrapper_confidence | first-class        |
| quality_override        | false              |
| path_taken              | standard           |
| self_check_answers      | null               |
| team_size               | solo               |
| deployment_target       | cloudflare-workers |
| ci_provider             | github-actions     |
| ci_default_flow         | auto-deploy-on-merge (branch `master` per hand-off body) |
| has_auth                | true               |
| has_payments            | false              |
| has_realtime            | false              |
| has_ai                  | false              |
| has_background_jobs     | false              |

## Next steps

Next: a future skill will set up agent context (CLAUDE.md, AGENTS.md). For now, your project is scaffolded and verified — happy hacking.

Useful manual steps in the meantime:
- `git init` (if you have not already) to start your own repo history.
- Review any `.scaffold` siblings the conflict policy created and decide which version of each file to keep.
- Address audit findings per your project's risk tolerance — the full breakdown is in this log.
