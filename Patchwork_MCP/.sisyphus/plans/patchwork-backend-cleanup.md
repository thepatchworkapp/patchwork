# Patchwork Backend Cleanup Tasks

## TL;DR

> **Quick Summary**: Complete remaining backend planning tasks - fix schema bug, create environment templates, add CI workflow, and document manual setup steps.
> 
> **Deliverables**:
> - Fixed CONVEX_SCHEMA.md (remove duplicate field)
> - MANUAL_STEPS.md (human action checklist)
> - .env.example template
> - GitHub Actions CI workflow
> - Updated IMPLEMENTATION_PLAN.md with test strategy
> 
> **Estimated Effort**: Short (1-2 hours)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 (schema fix) is independent; Tasks 2-5 can be parallel

---

## Context

### Original Request
Complete remaining tasks from backend planning session:
1. Fix duplicate `updatedAt` field bug in schema
2. Create MANUAL_STEPS.md for OAuth/Stripe/Convex setup
3. Create .env.example
4. Add GitHub Actions CI
5. Document test strategy in implementation plan

### Research Findings
- Schema bug confirmed at `taskerCategories` table (lines 164-168 have duplicate `updatedAt`)
- No .env.example or CI workflow currently exists
- Implementation plan has Phase 9 for testing but lacks specifics

---

## Work Objectives

### Core Objective
Finalize backend planning documentation so implementation can begin.

### Concrete Deliverables
- `Patchwork_MCP/CONVEX_SCHEMA.md` - Fixed schema (remove duplicate field)
- `Patchwork_MCP/MANUAL_STEPS.md` - Human action checklist
- `Patchwork_MCP/.env.example` - Environment variable template
- `Patchwork_MCP/.github/workflows/ci.yml` - CI workflow
- `Patchwork_MCP/IMPLEMENTATION_PLAN.md` - Updated with test details

### Definition of Done
- [ ] Schema compiles without duplicate field errors
- [ ] MANUAL_STEPS.md covers all OAuth, Stripe, and Convex account setup
- [ ] .env.example includes all required variables with placeholder values
- [ ] CI workflow runs build and (future) tests on push/PR
- [ ] Implementation plan includes Vitest setup and test file structure

### Must Have
- All manual human steps documented clearly
- CI that fails fast on build errors
- Test framework choice documented (Vitest)

### Must NOT Have (Guardrails)
- No actual implementation code (this is planning/docs only)
- No real secrets in .env.example
- No complex CI (keep it minimal - build + test)

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: NO (not yet)
- **User wants tests**: YES (documented in previous session)
- **Framework**: Vitest (matches Vite ecosystem)
- **QA approach**: Manual verification of documentation completeness

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Fix schema duplicate field
├── Task 2: Create MANUAL_STEPS.md
└── Task 3: Create .env.example

Wave 2 (After Wave 1):
├── Task 4: Create GitHub Actions CI
└── Task 5: Update IMPLEMENTATION_PLAN.md with test details

Wave 3 (Final):
└── Task 6: Verify all files and cross-references
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 6 | 2, 3 |
| 2 | None | 6 | 1, 3 |
| 3 | None | 4 | 1, 2 |
| 4 | 3 | 6 | 5 |
| 5 | None | 6 | 4 |
| 6 | 1, 2, 3, 4, 5 | None | None (final) |

---

## TODOs

- [ ] 1. Fix duplicate `updatedAt` field in CONVEX_SCHEMA.md

  **What to do**:
  - Open `Patchwork_MCP/CONVEX_SCHEMA.md`
  - Find `taskerCategories` table definition (around line 142)
  - Remove the standalone `updatedAt: v.number(),` at line 164
  - Keep only the `updatedAt` in the "Timestamps" section (line 168)

  **Must NOT do**:
  - Don't modify any other tables
  - Don't change the field name or type

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file, single line removal - trivial change
  - **Skills**: `[]` (no special skills needed)

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Task 6
  - **Blocked By**: None

  **References**:
  - `Patchwork_MCP/CONVEX_SCHEMA.md:142-172` - taskerCategories table definition

  **Acceptance Criteria**:
  - [ ] File contains exactly ONE `updatedAt` field in `taskerCategories`
  - [ ] The remaining `updatedAt` is under the `// Timestamps` comment
  - [ ] No TypeScript syntax errors in the schema block

  **Commit**: YES
  - Message: `fix(schema): remove duplicate updatedAt field in taskerCategories`
  - Files: `Patchwork_MCP/CONVEX_SCHEMA.md`

---

- [ ] 2. Create MANUAL_STEPS.md documenting all human-required actions

  **What to do**:
  - Create `Patchwork_MCP/MANUAL_STEPS.md`
  - Document all steps requiring human action before/during implementation:
    
    **Section 1: Account Setup**
    - Convex account creation (https://convex.dev)
    - Stripe account creation (https://stripe.com)
    - Google Cloud Console project for OAuth
    - Apple Developer account for Sign in with Apple
    
    **Section 2: OAuth Credentials**
    - Google OAuth client setup (detailed steps)
    - Apple Sign In setup (detailed steps)
    - Callback URLs to configure
    
    **Section 3: Stripe Configuration**
    - Create products for Basic and Premium plans
    - Set up webhook endpoint
    - Note price IDs for env vars
    
    **Section 4: Environment Variables**
    - List all variables and where to get each value
    - Link to .env.example
    
    **Section 5: Convex Setup**
    - `npx convex dev` first-time setup
    - Deployment commands
    
    **Section 6: Vercel Deployment**
    - Environment variables in Vercel
    - Domain configuration

  **Must NOT do**:
  - No actual credentials in the file
  - Don't duplicate content already in IMPLEMENTATION_PLAN.md

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation task requiring clear technical writing
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 6
  - **Blocked By**: None

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:23-44` - Prerequisites section
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:48-83` - Phase 0 environment section
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:152-177` - Environment variables

  **Acceptance Criteria**:
  - [ ] File exists at `Patchwork_MCP/MANUAL_STEPS.md`
  - [ ] Contains sections for: Account Setup, OAuth, Stripe, Env Vars, Convex, Vercel
  - [ ] Each OAuth provider has step-by-step instructions
  - [ ] Stripe product/webhook setup is documented
  - [ ] All callback URLs are specified

  **Commit**: YES
  - Message: `docs: add MANUAL_STEPS.md for human setup actions`
  - Files: `Patchwork_MCP/MANUAL_STEPS.md`

---

- [ ] 3. Create .env.example template file

  **What to do**:
  - Create `Patchwork_MCP/.env.example`
  - Include ALL environment variables from IMPLEMENTATION_PLAN.md
  - Use clear placeholder values (e.g., `your-google-client-id`)
  - Group by service (Convex, Better Auth, OAuth, Stripe)
  - Add comments explaining each variable

  **Content structure**:
  ```bash
  # ===================
  # Convex
  # ===================
  CONVEX_DEPLOYMENT=dev:your-project-name
  VITE_CONVEX_URL=https://your-project.convex.cloud
  
  # ===================
  # Better Auth
  # ===================
  BETTER_AUTH_SECRET=generate-32-char-random-string
  BETTER_AUTH_URL=http://localhost:3000
  VITE_BETTER_AUTH_URL=http://localhost:3000
  
  # ===================
  # OAuth Providers
  # ===================
  GOOGLE_CLIENT_ID=your-google-client-id
  GOOGLE_CLIENT_SECRET=your-google-client-secret
  APPLE_CLIENT_ID=your-apple-service-id
  APPLE_CLIENT_SECRET=your-apple-private-key
  
  # ===================
  # Stripe
  # ===================
  STRIPE_SECRET_KEY=sk_test_...
  STRIPE_WEBHOOK_SECRET=whsec_...
  STRIPE_PRICE_BASIC=price_...
  STRIPE_PRICE_PREMIUM=price_...
  
  # ===================
  # App
  # ===================
  APP_URL=http://localhost:3000
  ```

  **Must NOT do**:
  - No real secrets or API keys
  - Don't include variables not mentioned in the plan

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file creation with known content
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Task 4
  - **Blocked By**: None

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:48-75` - Phase 0 env template
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:152-177` - Phase 1 env vars

  **Acceptance Criteria**:
  - [ ] File exists at `Patchwork_MCP/.env.example`
  - [ ] Contains all 13+ environment variables
  - [ ] All values are placeholders (no real secrets)
  - [ ] Variables are grouped with comments
  - [ ] VITE_ prefixed vars included for client-side

  **Commit**: YES
  - Message: `chore: add .env.example template`
  - Files: `Patchwork_MCP/.env.example`

---

- [ ] 4. Create GitHub Actions CI workflow

  **What to do**:
  - Create directory `Patchwork_MCP/.github/workflows/`
  - Create `Patchwork_MCP/.github/workflows/ci.yml`
  - Workflow triggers: push to main, pull_request
  - Jobs:
    1. **build**: Install deps, run type-check, run build
    2. **test** (placeholder): Run `npm test` (will fail gracefully until tests exist)

  **Workflow content**:
  ```yaml
  name: CI
  
  on:
    push:
      branches: [main]
    pull_request:
      branches: [main]
  
  jobs:
    build:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: actions/setup-node@v4
          with:
            node-version: '20'
            cache: 'npm'
        - run: npm ci
        - run: npm run build
    
    test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - uses: actions/setup-node@v4
          with:
            node-version: '20'
            cache: 'npm'
        - run: npm ci
        - run: npm test --if-present
  ```

  **Must NOT do**:
  - No complex matrix builds
  - No deployment steps
  - Don't require env secrets for basic CI

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Standard boilerplate CI workflow
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 5)
  - **Blocks**: Task 6
  - **Blocked By**: Task 3 (.env.example should exist first for reference)

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:80-83` - Phase 0 CI mention
  - `Patchwork_MCP/package.json` - For script names

  **Acceptance Criteria**:
  - [ ] Directory `.github/workflows/` exists
  - [ ] File `ci.yml` exists with valid YAML syntax
  - [ ] Workflow triggers on push/PR to main
  - [ ] Build job runs `npm ci` and `npm run build`
  - [ ] Test job runs `npm test --if-present`

  **Commit**: YES
  - Message: `ci: add GitHub Actions workflow for build and test`
  - Files: `Patchwork_MCP/.github/workflows/ci.yml`

---

- [ ] 5. Update IMPLEMENTATION_PLAN.md with comprehensive test strategy

  **What to do**:
  - Enhance Phase 9 (Testing & Observability) section
  - Add Vitest setup instructions
  - Define test file structure
  - Add example test patterns for Convex functions
  - Define coverage targets

  **Content to add under Phase 9**:
  
  ```markdown
  ### 9.0 Test Framework Setup
  
  Install Vitest:
  ```bash
  npm install -D vitest @testing-library/react @testing-library/jest-dom
  ```
  
  Add to `package.json`:
  ```json
  {
    "scripts": {
      "test": "vitest",
      "test:coverage": "vitest --coverage"
    }
  }
  ```
  
  Create `vitest.config.ts`:
  ```typescript
  import { defineConfig } from 'vitest/config'
  
  export default defineConfig({
    test: {
      environment: 'jsdom',
      globals: true,
      setupFiles: ['./src/test/setup.ts'],
    },
  })
  ```
  
  ### 9.1 Test File Structure
  
  ```
  Patchwork_MCP/
  ├── src/
  │   ├── test/
  │   │   └── setup.ts           # Test setup (mocks, etc.)
  │   ├── components/
  │   │   └── __tests__/         # Component tests
  │   └── lib/
  │       └── __tests__/         # Utility tests
  └── convex/
      └── __tests__/             # Convex function tests (use convex-test)
  ```
  
  ### 9.2 Convex Testing
  
  Use `convex-test` for testing Convex functions:
  ```bash
  npm install -D convex-test
  ```
  
  Example test:
  ```typescript
  // convex/__tests__/users.test.ts
  import { convexTest } from "convex-test";
  import { describe, it, expect } from "vitest";
  import schema from "../schema";
  import { api } from "../_generated/api";
  
  describe("users", () => {
    it("creates a user profile", async () => {
      const t = convexTest(schema);
      // ... test implementation
    });
  });
  ```
  
  ### 9.3 Coverage Targets
  
  | Area | Target |
  |------|--------|
  | Convex mutations | 80% |
  | Convex queries | 70% |
  | React components | 60% |
  | Utilities | 90% |
  ```

  **Must NOT do**:
  - Don't remove existing Phase 9 content
  - Don't add actual test implementations

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Technical documentation update
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Task 6
  - **Blocked By**: None

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:694-704` - Current Phase 9 section
  - Vitest docs: https://vitest.dev/
  - convex-test docs: https://docs.convex.dev/testing

  **Acceptance Criteria**:
  - [ ] Phase 9 includes Vitest setup instructions
  - [ ] Test file structure is documented
  - [ ] Convex testing with `convex-test` is explained
  - [ ] Coverage targets are defined
  - [ ] `package.json` script additions are documented

  **Commit**: YES
  - Message: `docs(plan): add comprehensive test strategy to Phase 9`
  - Files: `Patchwork_MCP/IMPLEMENTATION_PLAN.md`

---

- [ ] 6. Verify all files and cross-references

  **What to do**:
  - Verify MANUAL_STEPS.md references .env.example correctly
  - Verify IMPLEMENTATION_PLAN.md references MANUAL_STEPS.md
  - Ensure no broken links or missing file references
  - Quick sanity check that all files exist

  **Must NOT do**:
  - Don't make content changes (just verify)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple verification task
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (final)
  - **Blocks**: None
  - **Blocked By**: Tasks 1, 2, 3, 4, 5

  **References**:
  - All files created in Tasks 1-5

  **Acceptance Criteria**:
  - [ ] All 5 files exist and are non-empty
  - [ ] MANUAL_STEPS.md links to .env.example
  - [ ] IMPLEMENTATION_PLAN.md mentions MANUAL_STEPS.md in prerequisites
  - [ ] No broken internal references

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files |
|------------|---------|-------|
| 1 | `fix(schema): remove duplicate updatedAt field in taskerCategories` | CONVEX_SCHEMA.md |
| 2 | `docs: add MANUAL_STEPS.md for human setup actions` | MANUAL_STEPS.md |
| 3 | `chore: add .env.example template` | .env.example |
| 4 | `ci: add GitHub Actions workflow for build and test` | .github/workflows/ci.yml |
| 5 | `docs(plan): add comprehensive test strategy to Phase 9` | IMPLEMENTATION_PLAN.md |

---

## Success Criteria

### Verification Commands
```bash
# Verify files exist
ls -la Patchwork_MCP/MANUAL_STEPS.md
ls -la Patchwork_MCP/.env.example
ls -la Patchwork_MCP/.github/workflows/ci.yml

# Verify schema has no duplicates
grep -c "updatedAt" Patchwork_MCP/CONVEX_SCHEMA.md | grep -v "^18$"  # Should NOT match (17 occurrences expected after fix)
```

### Final Checklist
- [ ] Schema bug fixed (single updatedAt in taskerCategories)
- [ ] MANUAL_STEPS.md covers all human actions
- [ ] .env.example has all variables
- [ ] CI workflow is valid YAML
- [ ] Test strategy documented in implementation plan
- [ ] All files cross-reference each other correctly
