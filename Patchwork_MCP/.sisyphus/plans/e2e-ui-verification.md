# E2E UI Verification - Comprehensive Smoke Test

## TL;DR

> **Quick Summary**: Comprehensive E2E smoke test suite to verify all Convex-wired screens work correctly after Phase 4 implementation. Uses Playwright with Email OTP auth, test data seeding, and automatic cleanup.
> 
> **Deliverables**:
> - Cleanup mutations in `convex/testing.ts`
> - Auth helpers extracted to `tests/ui/helpers/`
> - Comprehensive smoke test `tests/ui/smoke.test.ts`
> - Evidence screenshots in `.sisyphus/evidence/smoke-test/`
> 
> **Estimated Effort**: Medium (1-2 days)
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Task 1 → Task 2 → Task 3 → Task 4

---

## Context

### Original Request
Create comprehensive E2E UI tests to verify all Convex-wired screens work correctly after Phase 4 (Real-time Messaging) implementation.

### Interview Summary
**Key Discussions**:
- Comprehensive smoke test of ALL Convex-wired screens (not just Phase 4)
- Email OTP authentication - OTP codes visible in terminal logs
- Test data seeding + cleanup between runs
- Use Playwright (already configured)
- Happy path only, no error scenarios

**Research Findings**:
- Playwright config exists at root (`playwright.config.ts`)
- Existing test `messaging.test.ts` has working auth flow pattern
- No cleanup mutations exist yet - must create
- 7 screens use real Convex data

### Metis Review
**Identified Gaps** (addressed):
- No cleanup infrastructure → Create deleteTestUser, deleteByEmailPrefix mutations
- No auth helpers → Extract from messaging.test.ts into helpers/
- Vague "screens work" → Exact assertion table per screen
- Data collision risk → UUID-based test run IDs
- Categories might be empty → Seed-check in beforeAll

---

## Work Objectives

### Core Objective
Create a robust E2E smoke test suite that verifies all Convex-wired screens display real data correctly, with proper test isolation via seeding and cleanup.

### Concrete Deliverables
- `convex/testing.ts` - Add cleanup mutations (deleteTestUser, deleteByEmailPrefix, ensureCategoryExists)
- `tests/ui/helpers/auth.ts` - Extracted auth helpers (signUpAndLogin, fetchOtp)
- `tests/ui/helpers/cleanup.ts` - Cleanup utilities
- `tests/ui/smoke.test.ts` - Comprehensive smoke test covering 7 screens
- `.sisyphus/evidence/smoke-test/` - Screenshots at key checkpoints

### Definition of Done
- [ ] All 7 Convex-wired screens verified with specific assertions
- [ ] Test data cleaned up after each run (no orphaned data)
- [ ] Evidence screenshots captured for each screen
- [ ] Tests pass on fresh run AND repeated runs
- [ ] UUID-based test isolation prevents collisions

### Must Have
- Cleanup mutations to delete test users/data
- Auth helpers extracted and reusable
- Per-screen assertions matching exact table
- Evidence screenshots at defined checkpoints
- beforeAll seeds required data, afterAll cleans up

### Must NOT Have (Guardrails)
- Typing indicators, presence, reviews, job completion (deferred features)
- Error scenario tests (Phase 2)
- Mobile viewport tests
- Visual regression comparison
- More than 15 screenshots per test file
- Modifications to existing messaging.test.ts
- Arbitrary waitForTimeout() as primary wait strategy

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (Playwright configured, messaging.test.ts as reference)
- **User wants tests**: E2E with Playwright
- **Framework**: Playwright

### Automated Verification

All acceptance criteria are executable Playwright assertions:

| Screen | Assert These | Selectors |
|--------|-------------|-----------|
| SignIn | OTP input visible, verify succeeds, redirects | `input[autocomplete="one-time-code"]`, `text=Messages` |
| CreateProfile | Form submits, home screen appears | `text=Create your profile`, `button:has-text("Home")` |
| Profile | Name displays, city displays | `text={firstName}`, `text={city}` |
| Categories | ≥1 category visible | `[data-testid="category-item"]` or `.category-card` |
| Messages | Conversation list loads | `text={taskerName}` |
| Chat | Message sends, proposal appears | `text={messageText}`, `text=$60.00` |
| Jobs | Job visible after proposal accept | `text=in_progress` or `text=Job` |

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Add cleanup mutations to convex/testing.ts
└── Task 2: Extract auth helpers to tests/ui/helpers/

Wave 2 (After Wave 1):
├── Task 3: Create smoke.test.ts covering all screens
└── Task 4: Run verification and capture evidence

Critical Path: Task 1 → Task 3 → Task 4
Parallel Speedup: ~30% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 3 | 2 |
| 2 | None | 3 | 1 |
| 3 | 1, 2 | 4 | None |
| 4 | 3 | None | None |

---

## TODOs

### Task 1: Add Cleanup Mutations to convex/testing.ts

**What to do**:
- Add `deleteTestUser(email: string)` - Delete user by email
- Add `deleteByEmailPrefix(prefix: string)` - Delete all users matching prefix
- Add `ensureCategoryExists(name: string)` - Create category if not exists
- Add `cleanupConversations(userEmail: string)` - Delete user's conversations/messages

**Must NOT do**:
- Expose these endpoints without auth check (internal only)
- Delete non-test data (check email contains test patterns)
- Add production-facing mutations

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Small additions to existing file, straightforward mutations
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Task 2)
- **Blocks**: Task 3
- **Blocked By**: None

**References**:
- `Patchwork_MCP/convex/testing.ts` - Existing testing utilities (getOtp, forceCreateConversation)
- `Patchwork_MCP/convex/users.ts:createProfile` - Pattern for user mutations
- `Patchwork_MCP/convex/schema.ts` - User table structure for deletion queries

**Acceptance Criteria**:
```bash
# Agent verifies by running tests
npm run test:run
# Assert: All existing tests still pass

# Manual verification via Convex dashboard:
# 1. Create test user via signup
# 2. Call deleteTestUser with email
# 3. Verify user no longer in users table
```

- [ ] `deleteTestUser(email)` mutation exists
- [ ] `deleteByEmailPrefix(prefix)` mutation exists  
- [ ] `ensureCategoryExists(name)` mutation exists
- [ ] `cleanupConversations(userEmail)` mutation exists
- [ ] All mutations have email pattern validation (only delete @test.com or e2e_ prefix)
- [ ] Existing tests still pass: `npm run test:run`

**Commit**: YES
- Message: `feat(testing): add cleanup mutations for E2E test isolation`
- Files: `convex/testing.ts`
- Pre-commit: `npm run test:run`

---

### Task 2: Extract Auth Helpers to tests/ui/helpers/

**What to do**:
- Create `tests/ui/helpers/auth.ts`:
  - `signUpAndLogin(page, email, firstName, lastName, city)` - Full signup flow
  - `loginExisting(page, email)` - Login existing user
  - `fetchOtp(email)` - Get OTP code from Convex testing endpoint
- Create `tests/ui/helpers/cleanup.ts`:
  - `cleanupTestRun(prefix)` - Delete all data with prefix
  - `generateTestId()` - Generate `e2e_{uuid.slice(0,8)}`
- Export patterns from existing messaging.test.ts

**Must NOT do**:
- Modify messaging.test.ts (only extract patterns)
- Add OAuth automation (Email OTP only)
- Add error handling tests

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Code extraction and organization, no new logic
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Task 1)
- **Blocks**: Task 3
- **Blocked By**: None

**References**:
- `Patchwork_MCP/tests/ui/messaging.test.ts:22-116` - Auth flow to extract
- `Patchwork_MCP/tests/ui/messaging.test.ts:5-12` - Convex client setup
- `Patchwork_MCP/convex/testing.ts:getOtp` - OTP retrieval pattern

**Acceptance Criteria**:
```typescript
// Verify helpers compile
import { signUpAndLogin, fetchOtp } from './helpers/auth';
import { cleanupTestRun, generateTestId } from './helpers/cleanup';
```

- [ ] File exists: `tests/ui/helpers/auth.ts`
- [ ] File exists: `tests/ui/helpers/cleanup.ts`
- [ ] `signUpAndLogin()` handles: email entry → OTP → profile creation → home
- [ ] `fetchOtp()` retrieves OTP from `api.testing.getOtp`
- [ ] `generateTestId()` returns `e2e_{8-char-uuid}`
- [ ] TypeScript compiles: `npx tsc --noEmit`

**Commit**: YES
- Message: `feat(e2e): extract auth helpers for test reuse`
- Files: `tests/ui/helpers/auth.ts`, `tests/ui/helpers/cleanup.ts`
- Pre-commit: `npx tsc --noEmit`

---

### Task 3: Create Comprehensive smoke.test.ts

**What to do**:
- Create `tests/ui/smoke.test.ts` with single comprehensive flow:
  1. **Setup**: Generate test ID, seed category if needed
  2. **Auth**: Sign up seeker via Email OTP
  3. **CreateProfile**: Fill form, verify redirect to home
  4. **Profile**: Navigate, verify name/city display
  5. **Categories**: Navigate, verify ≥1 category visible
  6. **Messages**: Navigate, handle empty state OR verify conversation
  7. **Messaging flow**: Create conversation, send message, send proposal
  8. **Chat**: Verify message appears, proposal card visible
  9. **Jobs**: Navigate, verify job after proposal accept
  10. **Tasker Onboarding**: Sign up tasker, complete 4 steps
  11. **Cleanup**: Delete all test data

**Must NOT do**:
- Test deferred features (typing, presence, reviews)
- Test error scenarios
- Test mobile viewport
- Add visual regression
- Use waitForTimeout() as primary wait

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: Browser automation with Playwright, UI verification
- **Skills**: `["playwright"]`
  - playwright: Required for browser automation patterns

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 2 (sequential after Wave 1)
- **Blocks**: Task 4
- **Blocked By**: Tasks 1, 2

**References**:
- `Patchwork_MCP/tests/ui/messaging.test.ts` - Complete auth flow pattern
- `Patchwork_MCP/src/App.tsx:158-180` - Auth redirect logic
- `Patchwork_MCP/src/screens/SignIn.tsx` - SignIn UI structure
- `Patchwork_MCP/src/screens/CreateProfile.tsx` - Profile form fields
- `Patchwork_MCP/src/screens/Profile.tsx` - Profile display
- `Patchwork_MCP/src/screens/Categories.tsx` - Category list
- `Patchwork_MCP/src/screens/Messages.tsx` - Conversation list
- `Patchwork_MCP/src/screens/Chat.tsx` - Chat UI
- `tests/ui/helpers/auth.ts` - Auth helpers from Task 2
- `tests/ui/helpers/cleanup.ts` - Cleanup utilities from Task 2

**Acceptance Criteria**:

Screen-by-screen assertions:

```typescript
// SignIn
await expect(page.locator('input[autocomplete="one-time-code"]')).toBeVisible();
await expect(page.getByText('Messages')).toBeVisible({ timeout: 15000 });

// CreateProfile
await expect(page.getByText('Create your profile')).toBeVisible();
// After submit:
await expect(page.getByRole('navigation')).toContainText('Home');

// Profile
await expect(page.getByText(testUser.firstName)).toBeVisible();
await expect(page.getByText(testUser.city)).toBeVisible();

// Categories
const categoryCount = await page.locator('.category-card, [data-testid="category-item"]').count();
expect(categoryCount).toBeGreaterThan(0);

// Messages
// Either empty state OR conversation visible
const hasConversations = await page.locator('.conversation-item').count() > 0;

// Chat (after creating conversation)
await expect(page.getByText(sentMessageText)).toBeVisible();
await expect(page.locator('.proposal-card, [data-testid="proposal"]')).toBeVisible();

// Jobs (after proposal accept)
await expect(page.getByText(/pending|in_progress|Job/i)).toBeVisible();

// Tasker Onboarding (separate user)
await expect(page.getByText('Success')).toBeVisible();
```

- [ ] Test file: `tests/ui/smoke.test.ts`
- [ ] Uses helpers from `tests/ui/helpers/`
- [ ] beforeAll: generates test ID, seeds category
- [ ] afterAll: cleans up ALL test data
- [ ] Screenshots saved to `.sisyphus/evidence/smoke-test/`
- [ ] All 7 screens verified with exact assertions above
- [ ] No waitForTimeout() as primary wait strategy
- [ ] Test passes: `npx playwright test tests/ui/smoke.test.ts`

**Commit**: YES
- Message: `test(e2e): add comprehensive smoke test for all Convex-wired screens`
- Files: `tests/ui/smoke.test.ts`
- Pre-commit: `npx playwright test tests/ui/smoke.test.ts`

---

### Task 4: Run Verification and Capture Evidence

**What to do**:
- Run full smoke test suite
- Verify all screenshots captured in `.sisyphus/evidence/smoke-test/`
- Run test twice to verify no data collisions
- Document any mock screens encountered
- Verify cleanup worked (no orphaned test data in Convex)

**Must NOT do**:
- Add new features or tests
- Modify test logic based on failures (report issues instead)

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: Browser-based verification
- **Skills**: `["playwright"]`

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 2 (final)
- **Blocks**: None
- **Blocked By**: Task 3

**References**:
- `tests/ui/smoke.test.ts` - Test to run
- `.sisyphus/evidence/smoke-test/` - Evidence directory
- `Patchwork_MCP/convex/testing.ts` - Cleanup verification

**Acceptance Criteria**:

```bash
# Run tests twice - both should pass
npx playwright test tests/ui/smoke.test.ts
# Exit code: 0

npx playwright test tests/ui/smoke.test.ts
# Exit code: 0 (no data collision)

# Verify evidence
ls .sisyphus/evidence/smoke-test/
# Expected files:
# - 01-signin.png
# - 02-profile-created.png
# - 03-profile-view.png
# - 04-categories.png
# - 05-messages.png
# - 06-chat.png
# - 07-jobs.png
# - 08-tasker-onboarding-complete.png
```

- [ ] Test passes on first run
- [ ] Test passes on second run (no collision)
- [ ] 8 screenshots in `.sisyphus/evidence/smoke-test/`
- [ ] No orphaned test users in Convex (verify via dashboard)
- [ ] Document mock vs real data observations

**Commit**: YES
- Message: `test(e2e): verify smoke test passes with evidence capture`
- Files: Evidence screenshots (don't commit), any test fixes
- Pre-commit: `npx playwright test tests/ui/smoke.test.ts`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(testing): add cleanup mutations` | convex/testing.ts | npm run test:run |
| 2 | `feat(e2e): extract auth helpers` | tests/ui/helpers/*.ts | npx tsc --noEmit |
| 3 | `test(e2e): add smoke test` | tests/ui/smoke.test.ts | npx playwright test |
| 4 | `test(e2e): verify and document` | Any fixes | npx playwright test |

---

## Success Criteria

### Verification Commands
```bash
# Backend tests still pass
npm run test:run
# Expected: 53+ tests pass

# TypeScript compiles
npx tsc --noEmit
# Expected: No errors

# E2E smoke test passes
npx playwright test tests/ui/smoke.test.ts
# Expected: 1 test file, all assertions pass

# Evidence captured
ls .sisyphus/evidence/smoke-test/
# Expected: 8 screenshots

# No data collision on re-run
npx playwright test tests/ui/smoke.test.ts
# Expected: Still passes
```

### Final Checklist
- [ ] All "Must Have" features present
- [ ] All "Must NOT Have" guardrails respected
- [ ] 7 Convex-wired screens verified
- [ ] Test data properly cleaned up
- [ ] Evidence screenshots captured
- [ ] Test runs twice without collision
