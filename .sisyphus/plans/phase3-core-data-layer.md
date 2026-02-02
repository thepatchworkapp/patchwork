# Phase 3: Core Data Layer

## TL;DR

> **Quick Summary**: Expand Convex schema with tasker profile infrastructure, wire the frontend Profile and Onboarding screens to real data, and establish TDD patterns for all backend operations.
> 
> **Deliverables**:
> - 3 new database tables: `taskerProfiles`, `taskerCategories`, `categories`
> - Categories seed mutation with 15 service types
> - Tasker profile CRUD mutations + queries
> - Profile screen wired to Convex (replace mock data)
> - Tasker onboarding flow persisting to Convex
> - TDD tests for all backend functions
> - UI tests using agent-browser
> 
> **Estimated Effort**: Large (3-4 days)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Schema expansion -> Seed categories -> Backend functions -> Frontend wiring -> UI tests

---

## Context

### Original Request
Implement Phase 3 - Core Data Layer for Patchwork (mobile-first service marketplace). Complete the tasker profile infrastructure with TDD testing approach.

### Interview Summary
**Key Discussions**:
- Phase 1-2 (Auth) complete: Convex + Better Auth with Google OAuth + Email OTP
- Current schema has `users` + `seekerProfiles` - need 3 more tables
- Profile.tsx displays mock data (lines 111-145) - needs Convex wiring
- Tasker onboarding flow (1 -> 2 -> 4) has NO PERSISTENCE - data lost on refresh
- Display name input in TaskerOnboarding1 has no state binding (bug)
- Photos stored as base64 - should use Convex file storage

**Research Findings**:
- CONVEX_SCHEMA.md has complete schema specification for Phase 3 tables
- Existing test pattern in `convex/__tests__/users.test.ts` using convex-test + Vitest
- agent-browser supports programmatic API via BrowserManager class for Vitest integration
- Photos need upload flow: client gets URL -> uploads -> passes storage ID to mutation

### Metis Review
**Identified Gaps** (addressed):
- NO PERSISTENCE: Onboarding `onComplete()` just navigates - need `becomeTasker` mutation
- displayName bug: Input has no value/onChange props - fix state binding
- Photo upload: Need file storage upload flow before save
- Two getCurrentUser functions: `api.auth.getCurrentUser` vs `api.users.getCurrentUser` - plan uses the Convex users table version
- yearsExperience: Captured in UI but not in schema - EXCLUDE from Phase 3 (can add later)

---

## Work Objectives

### Core Objective
Build the complete tasker profile data layer with persistence, enabling users to become taskers, set up category-specific profiles with pricing, and view their real profile data.

### Concrete Deliverables
- `convex/schema.ts` - 3 new tables added
- `convex/categories.ts` - seed mutation + queries
- `convex/taskers.ts` - createTaskerProfile, updateTaskerProfile, addCategory, removeCategory, getTaskerProfile
- `convex/__tests__/categories.test.ts` - TDD tests
- `convex/__tests__/taskers.test.ts` - TDD tests
- `src/screens/TaskerOnboarding1.tsx` - displayName state binding fix
- `src/screens/TaskerOnboarding2.tsx` - photo upload to Convex storage
- `src/App.tsx` - wire onComplete to Convex mutation
- `src/screens/Profile.tsx` - replace mock data with Convex queries
- `tests/ui/tasker-onboarding.test.ts` - agent-browser UI tests

### Definition of Done
- [x] `npx convex dev` runs without schema errors
- [x] `bun test` passes all backend tests (categories, taskers)
- [x] Tasker onboarding flow persists data to Convex database
- [x] Profile screen displays real user/tasker data from Convex
- [x] agent-browser UI tests pass for onboarding flow

### Must Have
- Schema with all 3 tables and indexes per CONVEX_SCHEMA.md
- Categories seed with 15 service types
- `becomeTasker` mutation called at onboarding completion
- Display name captured and persisted
- Photo upload to Convex storage (not base64 in DB)
- Profile screen shows real data from Convex

### Must NOT Have (Guardrails)
- NO jobs/requests tables (Phase 4-5)
- NO messaging tables (Phase 4)
- NO payment/subscription logic (Phase 7)
- NO geospatial search (Phase 6)
- NO yearsExperience field (not in schema spec)
- NO premium feature enforcement (subscription plan stored but not enforced)
- NO changes to Better Auth configuration

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (convex-test + Vitest configured)
- **User wants tests**: TDD
- **Framework**: Vitest with convex-test

### TDD Workflow

Each backend TODO follows RED-GREEN-REFACTOR:

1. **RED**: Write failing test first
   - Test file: `convex/__tests__/{module}.test.ts`
   - Test command: `bun test convex/__tests__/{module}.test.ts`
   - Expected: FAIL (test exists, implementation doesn't)
2. **GREEN**: Implement minimum code to pass
   - Command: `bun test convex/__tests__/{module}.test.ts`
   - Expected: PASS
3. **REFACTOR**: Clean up while keeping green
   - Command: `bun test convex/__tests__/{module}.test.ts`
   - Expected: PASS (still)

### UI Testing with agent-browser

```bash
# Install agent-browser
npm install -g agent-browser
agent-browser install

# Test pattern
agent-browser open http://localhost:5173
agent-browser snapshot -i
agent-browser fill @e1 "Display Name"
agent-browser click @e2
agent-browser wait --load networkidle
agent-browser screenshot ./evidence/onboarding-complete.png
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
+-- Task 1: Expand schema.ts with 3 new tables (no deps)
+-- Task 2: Write categories tests (RED) + seed mutation (no deps)

Wave 2 (After Wave 1):
+-- Task 3: Write tasker profile tests (RED) + mutations (depends: 1)
+-- Task 4: Fix TaskerOnboarding1 displayName binding (depends: 1)
+-- Task 5: Add photo upload flow to files.ts (depends: 1)

Wave 3 (After Wave 2):
+-- Task 6: Wire TaskerOnboarding2 photo upload (depends: 5)
+-- Task 7: Wire App.tsx onComplete to becomeTasker mutation (depends: 3, 4, 6)
+-- Task 8: Wire Profile.tsx to Convex queries (depends: 3)

Wave 4 (After Wave 3):
+-- Task 9: UI tests with agent-browser (depends: 7, 8)

Critical Path: Task 1 -> Task 3 -> Task 7 -> Task 9
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 3, 4, 5 | 2 |
| 2 | None | None (standalone) | 1 |
| 3 | 1 | 7, 8 | 4, 5 |
| 4 | 1 | 7 | 3, 5 |
| 5 | 1 | 6 | 3, 4 |
| 6 | 5 | 7 | None |
| 7 | 3, 4, 6 | 9 | 8 |
| 8 | 3 | 9 | 7 |
| 9 | 7, 8 | None (final) | None |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Dispatch |
|------|-------|---------------------|
| 1 | 1, 2 | delegate_task(category="quick", run_in_background=true) each |
| 2 | 3, 4, 5 | delegate_task(category="unspecified-low", run_in_background=true) each |
| 3 | 6, 7, 8 | delegate_task(category="unspecified-low", run_in_background=false) sequential |
| 4 | 9 | delegate_task(category="unspecified-high", load_skills=["playwright"]) |

---

## TODOs

### - [x] 1. Expand schema.ts with 3 new tables

**What to do**:
- Add `taskerProfiles` table definition with all fields from CONVEX_SCHEMA.md
- Add `taskerCategories` table definition with all fields
- Add `categories` table definition with all fields
- Add all required indexes for each table
- Run `npx convex dev` to validate schema

**Must NOT do**:
- Do NOT add jobRequests, jobs, messages, conversations, proposals, reviews, subscriptions tables (later phases)
- Do NOT modify existing users or seekerProfiles tables

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Single file modification, well-defined schema spec to follow
- **Skills**: `[]`
  - No special skills needed - straightforward schema copy from spec

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Task 2)
- **Blocks**: Tasks 3, 4, 5
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References**:
- `Patchwork_MCP/convex/schema.ts:1-43` - Current schema structure, existing users and seekerProfiles tables to understand the pattern

**API/Type References**:
- `Patchwork_MCP/CONVEX_SCHEMA.md:87-137` - taskerProfiles table definition with all fields and indexes
- `Patchwork_MCP/CONVEX_SCHEMA.md:139-170` - taskerCategories table definition with all fields and indexes
- `Patchwork_MCP/CONVEX_SCHEMA.md:198-207` - categories table definition with all fields and indexes

**Documentation References**:
- `Patchwork_MCP/CONVEX_SCHEMA.md:519-531` - Index documentation explaining why each index exists

**Acceptance Criteria**:

```bash
# Agent runs:
npx convex dev --once 2>&1 | grep -E "(error|Error|SUCCESS)"
# Assert: No schema validation errors
# Assert: Output includes schema deployment success
```

**Evidence to Capture:**
- [x] Terminal output from `npx convex dev --once`
- [x] Convex dashboard screenshot showing new tables

**Commit**: YES
- Message: `feat(convex): add taskerProfiles, taskerCategories, categories tables`
- Files: `convex/schema.ts`
- Pre-commit: `npx convex dev --once`

---

### - [x] 2. Write categories tests (TDD) + seed mutation

**What to do**:
- **RED**: Create `convex/__tests__/categories.test.ts` with tests for:
  - `seedCategories` mutation creates 15 categories
  - `seedCategories` is idempotent (running twice doesn't duplicate)
  - `listCategories` query returns all active categories sorted by sortOrder
  - `getCategoryBySlug` query returns single category
- **GREEN**: Create `convex/categories.ts` with:
  - `seedCategories` mutation (copy from CONVEX_SCHEMA.md:582-620)
  - `listCategories` query
  - `getCategoryBySlug` query
- **REFACTOR**: Clean up any duplication

**Must NOT do**:
- Do NOT hardcode categories in frontend - they come from DB
- Do NOT add category CRUD (admin feature for later)

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Straightforward TDD task, seed data defined in spec
- **Skills**: `[]`
  - No special skills needed

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Task 1)
- **Blocks**: None (other tasks don't depend on categories directly)
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References**:
- `Patchwork_MCP/convex/__tests__/users.test.ts:1-67` - Test structure pattern using convex-test, how to set up test context and identity
- `Patchwork_MCP/convex/users.ts` - Mutation/query structure pattern

**API/Type References**:
- `Patchwork_MCP/CONVEX_SCHEMA.md:582-620` - Exact seedCategories implementation to copy
- `Patchwork_MCP/CONVEX_SCHEMA.md:198-207` - Categories table schema for query return types

**Documentation References**:
- `Patchwork_MCP/CONVEX_SCHEMA.md:623` - Run command: `npx convex run categories:seedCategories`

**Acceptance Criteria**:

**TDD (tests enabled):**
- [x] Test file created: `convex/__tests__/categories.test.ts`
- [x] Tests cover: seedCategories creates 15 categories, idempotent behavior, listCategories sorted
- [x] `bun test convex/__tests__/categories.test.ts` -> PASS (all tests green)

**Automated Verification:**
```bash
# Agent runs:
bun test convex/__tests__/categories.test.ts 2>&1 | tail -20
# Assert: All tests pass
# Assert: No failures
```

**Evidence to Capture:**
- [x] Terminal output from test run showing pass/fail counts

**Commit**: YES
- Message: `feat(convex): add categories seed mutation with TDD tests`
- Files: `convex/categories.ts`, `convex/__tests__/categories.test.ts`
- Pre-commit: `bun test convex/__tests__/categories.test.ts`

---

### - [x] 3. Write tasker profile tests (TDD) + mutations

**What to do**:
- **RED**: Create `convex/__tests__/taskers.test.ts` with tests for:
  - `createTaskerProfile` - creates taskerProfile + first taskerCategory
  - `createTaskerProfile` - throws if user already has tasker profile
  - `createTaskerProfile` - updates user.roles.isTasker to true
  - `getTaskerProfile` - returns full profile with categories
  - `getTaskerProfile` - returns null if not a tasker
  - `updateTaskerProfile` - updates displayName, bio
  - `addTaskerCategory` - adds new category to existing profile
  - `removeTaskerCategory` - removes category (keeps profile if other categories exist)
- **GREEN**: Create `convex/taskers.ts` with:
  - `createTaskerProfile` mutation
  - `getTaskerProfile` query
  - `updateTaskerProfile` mutation
  - `addTaskerCategory` mutation
  - `removeTaskerCategory` mutation
- **REFACTOR**: Extract shared validation logic

**Must NOT do**:
- Do NOT implement subscription checks (later phase)
- Do NOT implement premium features logic
- Do NOT implement geospatial indexing

**Recommended Agent Profile**:
- **Category**: `unspecified-low`
  - Reason: Multiple functions but straightforward CRUD, TDD provides clear spec
- **Skills**: `[]`
  - No special skills needed

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 4, 5)
- **Blocks**: Tasks 7, 8
- **Blocked By**: Task 1 (schema must exist)

**References**:

**Pattern References**:
- `Patchwork_MCP/convex/__tests__/users.test.ts:1-67` - Test structure pattern, how to mock auth identity
- `Patchwork_MCP/convex/users.ts:1-80` - Mutation pattern: auth check, validation, insert, return

**API/Type References**:
- `Patchwork_MCP/CONVEX_SCHEMA.md:87-137` - taskerProfiles table structure (what to insert)
- `Patchwork_MCP/CONVEX_SCHEMA.md:139-170` - taskerCategories table structure (what to insert)
- `Patchwork_MCP/convex/schema.ts` - Actual schema types after Task 1

**Documentation References**:
- `Patchwork_MCP/CONVEX_SCHEMA.md:543-574` - File storage upload pattern (for photo IDs)

**Acceptance Criteria**:

**TDD (tests enabled):**
- [x] Test file created: `convex/__tests__/taskers.test.ts`
- [x] Tests cover: create profile, get profile, update profile, add/remove category
- [x] `bun test convex/__tests__/taskers.test.ts` -> PASS (all tests green)

**Automated Verification:**
```bash
# Agent runs:
bun test convex/__tests__/taskers.test.ts 2>&1 | tail -20
# Assert: All tests pass (8+ tests)
# Assert: No failures
```

**Evidence to Capture:**
- [x] Terminal output showing all test cases pass

**Commit**: YES
- Message: `feat(convex): add tasker profile CRUD with TDD tests`
- Files: `convex/taskers.ts`, `convex/__tests__/taskers.test.ts`
- Pre-commit: `bun test convex/__tests__/taskers.test.ts`

---

### - [x] 4. Fix TaskerOnboarding1 displayName state binding

**What to do**:
- Add `displayName` state to App.tsx (or pass via props)
- Add `value` and `onChange` props to Input component in TaskerOnboarding1.tsx (line 88-91)
- Pass `displayName` and `onDisplayNameChange` as props from App.tsx
- Update TaskerOnboarding1Props interface

**Must NOT do**:
- Do NOT add form validation yet (keep it simple)
- Do NOT change the visual design

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Small fix, adding 2 props to existing component
- **Skills**: `[]`
  - No special skills needed

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 3, 5)
- **Blocks**: Task 7
- **Blocked By**: Task 1 (schema context, but not strictly required)

**References**:

**Pattern References**:
- `Patchwork_MCP/src/screens/TaskerOnboarding1.tsx:14-16` - Existing props pattern (selectedCategories, onCategoriesChange)
- `Patchwork_MCP/src/App.tsx:82-97` - Existing tasker state in App.tsx

**API/Type References**:
- `Patchwork_MCP/src/screens/TaskerOnboarding1.tsx:9-16` - TaskerOnboarding1Props interface to extend

**Acceptance Criteria**:

**Automated Verification (using Bash to check code):**
```bash
# Agent runs:
grep -n "displayName" Patchwork_MCP/src/screens/TaskerOnboarding1.tsx | head -5
# Assert: Shows displayName in props interface
# Assert: Shows value={displayName} on Input

grep -n "displayName" Patchwork_MCP/src/App.tsx | head -5
# Assert: Shows useState for displayName
```

**Evidence to Capture:**
- [x] grep output showing displayName wiring in both files

**Commit**: YES (groups with Task 7)
- Message: `fix(ui): wire displayName input in TaskerOnboarding1`
- Files: `src/screens/TaskerOnboarding1.tsx`, `src/App.tsx`
- Pre-commit: `bun run build` (type check)

---

### - [x] 5. Add photo upload mutations to files.ts

**What to do**:
- Create `convex/files.ts` (or extend if exists) with:
  - `generateUploadUrl` mutation - returns Convex storage upload URL
  - `getImageUrl` query - converts storage ID to URL
- Follow Convex file storage pattern from docs

**Must NOT do**:
- Do NOT implement image resizing/optimization
- Do NOT add file size limits (Convex handles this)

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Standard Convex pattern, 2 small functions
- **Skills**: `[]`
  - No special skills needed

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 3, 4)
- **Blocks**: Task 6
- **Blocked By**: Task 1 (schema context)

**References**:

**Pattern References**:
- `Patchwork_MCP/convex/files.ts` - May already exist from Phase 1-2 (profile photo upload)

**Documentation References**:
- `Patchwork_MCP/CONVEX_SCHEMA.md:543-553` - File storage pattern documentation

**External References**:
- Convex file storage docs: https://docs.convex.dev/file-storage

**Acceptance Criteria**:

**Automated Verification:**
```bash
# Agent runs:
grep -n "generateUploadUrl\|getImageUrl" Patchwork_MCP/convex/files.ts
# Assert: Both functions exist
# Assert: generateUploadUrl uses ctx.storage.generateUploadUrl()
```

**Evidence to Capture:**
- [x] grep output showing both functions exist

**Commit**: YES (groups with Task 6)
- Message: `feat(convex): add file upload utilities for category photos`
- Files: `convex/files.ts`
- Pre-commit: `npx convex dev --once`

---

### - [x] 6. Wire TaskerOnboarding2 photo upload to Convex storage

**What to do**:
- Import `useMutation` from convex/react
- Replace base64 FileReader with:
  1. Call `generateUploadUrl` mutation
  2. Upload file to URL with fetch
  3. Store returned storage ID instead of base64
- Update `categoryPhotos` state to hold storage IDs (string[])
- Update `onNext` callback to pass storage IDs

**Must NOT do**:
- Do NOT keep base64 as fallback
- Do NOT add loading states for upload (keep simple)

**Recommended Agent Profile**:
- **Category**: `unspecified-low`
  - Reason: Requires understanding Convex file upload flow
- **Skills**: `[]`
  - No special skills needed

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 3 (sequential after Task 5)
- **Blocks**: Task 7
- **Blocked By**: Task 5 (needs generateUploadUrl mutation)

**References**:

**Pattern References**:
- `Patchwork_MCP/src/screens/TaskerOnboarding2.tsx:206-232` - Current photo upload code to replace
- `Patchwork_MCP/src/screens/CreateProfile.tsx` - May have existing Convex upload pattern from profile photo

**API/Type References**:
- `Patchwork_MCP/convex/files.ts` - generateUploadUrl mutation (from Task 5)

**Documentation References**:
- Convex React file upload: https://docs.convex.dev/file-storage/upload-files#uploading-files-from-react

**Acceptance Criteria**:

**Automated Verification:**
```bash
# Agent runs:
grep -n "generateUploadUrl\|useMutation" Patchwork_MCP/src/screens/TaskerOnboarding2.tsx | head -5
# Assert: Shows useMutation import
# Assert: Shows generateUploadUrl usage

grep -n "readAsDataURL" Patchwork_MCP/src/screens/TaskerOnboarding2.tsx
# Assert: No results (base64 removed)
```

**Evidence to Capture:**
- [x] grep output confirming Convex upload, no base64

**Commit**: YES (groups with Task 5)
- Message: `feat(ui): upload category photos to Convex storage`
- Files: `src/screens/TaskerOnboarding2.tsx`
- Pre-commit: `bun run build`

---

### - [x] 7. Wire App.tsx onComplete to becomeTasker mutation

**What to do**:
- Create `becomeTasker` mutation in `convex/taskers.ts` that:
  1. Creates taskerProfile record
  2. Creates first taskerCategory record
  3. Updates user.roles.isTasker = true
  4. Returns taskerProfileId
- In App.tsx, replace `navigate("tasker-success")` in `handleOnboarding4Complete`:
  1. Call `becomeTasker` mutation with all collected data
  2. On success, navigate to "tasker-success"
  3. Clear onboarding state

**Must NOT do**:
- Do NOT show loading/error UI (keep simple for Phase 3)
- Do NOT validate all fields (trust the UI for now)

**Recommended Agent Profile**:
- **Category**: `unspecified-low`
  - Reason: Connects multiple pieces, needs careful data threading
- **Skills**: `[]`
  - No special skills needed

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Task 8)
- **Blocks**: Task 9
- **Blocked By**: Tasks 3, 4, 6

**References**:

**Pattern References**:
- `Patchwork_MCP/src/App.tsx:200-210` - Current handleOnboarding4Complete function
- `Patchwork_MCP/src/App.tsx:82-97` - All tasker-related state to collect

**API/Type References**:
- `Patchwork_MCP/convex/taskers.ts` - createTaskerProfile mutation (from Task 3)
- `Patchwork_MCP/CONVEX_SCHEMA.md:87-170` - Data shapes for taskerProfile + taskerCategory

**Acceptance Criteria**:

**Automated Verification (using interactive_bash for full flow):**
```bash
# Agent runs:
grep -n "becomeTasker\|useMutation" Patchwork_MCP/src/App.tsx | head -10
# Assert: Shows useMutation import
# Assert: Shows becomeTasker mutation call in handleOnboarding4Complete
```

**UI Verification (using playwright skill):**
```
1. Navigate to: http://localhost:5173
2. Complete auth flow (if needed)
3. Click "Become a Tasker"
4. Fill TaskerOnboarding1: select category, enter display name
5. Continue to TaskerOnboarding2: set rate, radius, bio
6. Continue to TaskerOnboarding4: accept terms, complete
7. Assert: Navigates to success screen
8. Open Convex dashboard: verify taskerProfiles has new record
```

**Evidence to Capture:**
- [x] grep output showing mutation wiring
- [x] Convex dashboard screenshot showing new taskerProfile record

**Commit**: YES
- Message: `feat(ui): wire tasker onboarding flow to Convex persistence`
- Files: `src/App.tsx`, `convex/taskers.ts`
- Pre-commit: `bun test convex/__tests__/taskers.test.ts && bun run build`

---

### - [x] 8. Wire Profile.tsx to Convex queries

**What to do**:
- Import `useQuery` from convex/react
- Replace ALL mock data (lines 111-145) with:
  - `useQuery(api.users.getCurrentUser)` for user data
  - `useQuery(api.taskers.getTaskerProfile)` for tasker data
- Handle loading state (show skeleton or spinner)
- Handle case where user is not a tasker (hide tasker section)
- Wire category edit modal to `updateTaskerCategory` mutation

**Must NOT do**:
- Do NOT add edit functionality for user profile (Phase 4)
- Do NOT add subscription upgrade buttons (Phase 7)
- Do NOT modify the visual design

**Recommended Agent Profile**:
- **Category**: `unspecified-low`
  - Reason: Significant refactor, but well-defined replacement
- **Skills**: `[]`
  - No special skills needed

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Task 7)
- **Blocks**: Task 9
- **Blocked By**: Task 3 (needs getTaskerProfile query)

**References**:

**Pattern References**:
- `Patchwork_MCP/src/screens/Profile.tsx:111-145` - Mock data to replace
- `Patchwork_MCP/src/screens/Profile.tsx:180-250` - Category modal that needs mutation wiring
- `Patchwork_MCP/src/App.tsx:120-130` - Pattern for useQuery with loading handling

**API/Type References**:
- `Patchwork_MCP/convex/users.ts` - getCurrentUser query
- `Patchwork_MCP/convex/taskers.ts` - getTaskerProfile query (from Task 3)

**Acceptance Criteria**:

**Automated Verification:**
```bash
# Agent runs:
grep -n "mock\|Mock\|MOCK" Patchwork_MCP/src/screens/Profile.tsx
# Assert: No results (all mock data removed)

grep -n "useQuery" Patchwork_MCP/src/screens/Profile.tsx | head -5
# Assert: Shows useQuery imports and usage
```

**UI Verification (using playwright skill):**
```
1. Navigate to: http://localhost:5173
2. Login as existing user who completed tasker onboarding
3. Navigate to Profile tab
4. Assert: User name matches Convex data
5. Assert: Tasker section shows real categories and stats
6. Screenshot: .sisyphus/evidence/task-8-profile-real-data.png
```

**Evidence to Capture:**
- [x] grep output confirming no mock data, useQuery present
- [x] Screenshot of Profile with real data

**Commit**: YES
- Message: `feat(ui): wire Profile screen to Convex queries`
- Files: `src/screens/Profile.tsx`
- Pre-commit: `bun run build`

---

### - [x] 9. Create agent-browser UI tests for tasker flow

**What to do**:
- Install agent-browser globally: `npm install -g agent-browser && agent-browser install`
- Create `tests/ui/tasker-onboarding.test.ts` with Vitest + BrowserManager:
  - Test: Complete tasker onboarding flow end-to-end
  - Test: Profile shows correct data after onboarding
  - Test: Category edit modal saves changes
- Save screenshots as evidence in `.sisyphus/evidence/`

**Must NOT do**:
- Do NOT test auth flow (covered in Phase 1-2)
- Do NOT test error cases (keep happy path for now)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: New testing pattern, browser automation complexity
- **Skills**: `["playwright"]`
  - playwright skill provides browser automation patterns that apply to agent-browser

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 4 (final)
- **Blocks**: None (final task)
- **Blocked By**: Tasks 7, 8

**References**:

**Pattern References**:
- `Patchwork_MCP/convex/__tests__/users.test.ts` - Vitest test structure pattern

**External References**:
- agent-browser GitHub: https://github.com/vercel-labs/agent-browser
- BrowserManager API: Import from 'agent-browser', use launch(), getPage(), close()

**Documentation References**:
- Draft file `.sisyphus/drafts/phase3-core-data-layer.md` - Contains agent-browser research with code examples

**Acceptance Criteria**:

**Automated Verification:**
```bash
# Agent runs:
bun test tests/ui/tasker-onboarding.test.ts 2>&1 | tail -20
# Assert: All UI tests pass
# Assert: Screenshots exist in .sisyphus/evidence/
```

**Evidence to Capture:**
- [x] Terminal output showing UI test results
- [x] Screenshot files in .sisyphus/evidence/

**Commit**: YES
- Message: `test(ui): add agent-browser E2E tests for tasker onboarding`
- Files: `tests/ui/tasker-onboarding.test.ts`, `.sisyphus/evidence/*.png`
- Pre-commit: `bun test tests/ui/`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(convex): add taskerProfiles, taskerCategories, categories tables` | `convex/schema.ts` | `npx convex dev --once` |
| 2 | `feat(convex): add categories seed mutation with TDD tests` | `convex/categories.ts`, `convex/__tests__/categories.test.ts` | `bun test convex/__tests__/categories.test.ts` |
| 3 | `feat(convex): add tasker profile CRUD with TDD tests` | `convex/taskers.ts`, `convex/__tests__/taskers.test.ts` | `bun test convex/__tests__/taskers.test.ts` |
| 4+6+5 | `feat(ui): wire displayName and photo upload in onboarding` | `src/screens/TaskerOnboarding1.tsx`, `src/screens/TaskerOnboarding2.tsx`, `src/App.tsx`, `convex/files.ts` | `bun run build` |
| 7 | `feat(ui): wire tasker onboarding flow to Convex persistence` | `src/App.tsx`, `convex/taskers.ts` | `bun test && bun run build` |
| 8 | `feat(ui): wire Profile screen to Convex queries` | `src/screens/Profile.tsx` | `bun run build` |
| 9 | `test(ui): add agent-browser E2E tests for tasker onboarding` | `tests/ui/tasker-onboarding.test.ts` | `bun test tests/ui/` |

---

## Success Criteria

### Verification Commands
```bash
# Schema deployed successfully
npx convex dev --once  # Expected: No errors

# All backend tests pass
bun test convex/__tests__/  # Expected: All tests green

# App builds without errors
bun run build  # Expected: Build successful

# UI tests pass
bun test tests/ui/  # Expected: All tests green
```

### Final Checklist
- [x] All 3 new tables exist in Convex dashboard
- [x] Categories seeded (15 active categories)
- [x] Tasker onboarding persists to database (data survives refresh)
- [x] Profile screen shows real user/tasker data
- [x] All TDD tests pass
- [x] UI tests pass with screenshots as evidence
- [x] No mock data remains in Profile.tsx
