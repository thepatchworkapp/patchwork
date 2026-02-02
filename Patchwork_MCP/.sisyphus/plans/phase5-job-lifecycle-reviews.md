# Phase 5: Job Lifecycle + Reviews

## TL;DR

> **Quick Summary**: Complete job lifecycle (status transitions) and add bidirectional blind reviews with rating aggregation. Seeker completes jobs, both parties review within 30 days.
> 
> **Deliverables**:
> - Reviews table in schema
> - Job status mutations (completeJob)
> - Review mutations (createReview) with 30-day window
> - Rating aggregation for profiles
> - Jobs.tsx and JobDetail.tsx wired to Convex
> - Chat.tsx completion + review flow connected
> 
> **Estimated Effort**: Medium-Large (2-3 days)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Schema → Backend mutations → Tests → Frontend wiring

---

## Context

### Original Request
Complete Phase 5 from IMPLEMENTATION_PLAN.md - Job Lifecycle + Reviews with bidirectional blind reviews.

### Interview Summary
**Key Discussions**:
- Bidirectional reviews (seeker ↔ tasker)
- **Blind reviews**: Hidden until both parties submit
- Seeker-only can mark jobs complete
- Job starts automatically on proposal accept (pending → in_progress)
- 30-day review window after completion
- No review editing after submission
- No photo uploads in reviews (deferred)
- Require review text (10+ chars)

**Research Findings**:
- Job schema exists with status enum (pending, in_progress, completed, cancelled, disputed)
- Jobs table has `seekerReviewId` and `taskerReviewId` fields ready
- Profile tables have rating/reviewCount fields
- Chat.tsx has "Complete Job" button + review modal (partially built)
- LeaveReview.tsx exists but disconnected
- 5 job tests exist

### Metis Review
**Identified Gaps** (addressed):
- Who completes jobs: resolved → Seeker only
- Pending → in_progress trigger: resolved → Automatic on proposal accept
- Blind review: resolved → Yes, hidden until both submit
- Review text requirement: resolved → 10+ chars required
- Duplicate review prevention: resolved → Unique index on (jobId, reviewerId)

---

## Work Objectives

### Core Objective
Complete the job lifecycle with status transitions and add a bidirectional blind review system that aggregates ratings to tasker and seeker profiles.

### Concrete Deliverables
- `convex/schema.ts` - Add reviews table with unique index
- `convex/jobs.ts` - Add `completeJob` mutation (seeker only)
- `convex/proposals.ts` - Update `acceptProposal` to set job status = in_progress
- `convex/reviews.ts` - Create CRUD operations with 30-day window, blind review logic
- `convex/__tests__/reviews.test.ts` - TDD tests for review system
- `src/screens/Jobs.tsx` - Wire to real Convex data
- `src/screens/JobDetail.tsx` - Wire to real data + "Leave Review" button
- `src/screens/Chat.tsx` - Wire "Complete Job" and review modal to mutations

### Definition of Done
- [x] Reviews table created with unique (jobId, reviewerId) constraint
- [x] Job completes only when seeker calls completeJob
- [x] Job status auto-transitions to in_progress on proposal accept
- [x] Reviews hidden until both parties submit (blind review)
- [x] 30-day review window enforced
- [x] Review text required (10+ chars)
- [x] Rating aggregation updates profile stats atomically
- [x] 10+ new backend tests passing
- [x] Jobs.tsx shows real job data
- [x] Complete Job → Review flow works end-to-end

### Must Have
- Seeker-only job completion
- Automatic pending → in_progress on proposal accept
- Bidirectional blind reviews
- 30-day review window enforcement
- Rating aggregation (profile-level)
- Review text requirement (10+ chars)
- Unique review per party per job

### Must NOT Have (Guardrails)
- cancelJob mutation (deferred)
- disputeJob mutation (deferred)
- Review editing/deletion
- Photo uploads in reviews
- Review responses/replies
- Category-specific rating updates (defer to later)
- Public review pages

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (convex-test, vitest configured)
- **User wants tests**: TDD
- **Framework**: vitest + convex-test

### TDD Approach
Each backend TODO follows RED-GREEN-REFACTOR:
1. **RED**: Write failing test in `convex/__tests__/`
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Clean up while keeping green

**Test Commands:**
```bash
npm run test:run           # Run all tests once
npm run test               # Watch mode
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Add reviews table to schema
└── Task 2: Update acceptProposal for auto in_progress

Wave 2 (After Wave 1):
├── Task 3: Create completeJob mutation (TDD)
├── Task 4: Create review mutations (TDD)
└── Task 5: Add rating aggregation logic

Wave 3 (After Wave 2):
├── Task 6: Wire Jobs.tsx to Convex
├── Task 7: Wire JobDetail.tsx to Convex
├── Task 8: Wire Chat.tsx completion + review flow
└── Task 9: E2E verification

Critical Path: Task 1 → Task 4 → Task 5 → Task 8 → Task 9
Parallel Speedup: ~35% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 4 | 2 |
| 2 | None | 3 | 1 |
| 3 | 2 | 8 | 4, 5 |
| 4 | 1 | 5, 8 | 3 |
| 5 | 4 | 8 | 3 |
| 6 | 3 | 9 | 7 |
| 7 | 3 | 9 | 6 |
| 8 | 3, 4, 5 | 9 | - |
| 9 | 6, 7, 8 | None | - |

---

## TODOs

### Task 1: Add Reviews Table to Schema

**What to do**:
- Add `reviews` table to `convex/schema.ts`
- Fields: jobId, reviewerId, revieweeId, rating (1-5), text, createdAt
- Add unique index on (jobId, reviewerId) to prevent duplicates
- Add indexes: by_job, by_reviewer, by_reviewee

**Must NOT do**:
- Add photos field (deferred)
- Add editedAt or any edit-related fields
- Add response/reply fields

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Schema additions are straightforward
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Task 2)
- **Blocks**: Task 4
- **Blocked By**: None

**References**:
- `Patchwork_MCP/convex/schema.ts:263-309` - Jobs table with seekerReviewId/taskerReviewId
- `Patchwork_MCP/CONVEX_SCHEMA.md` - Schema design reference

**Acceptance Criteria**:
- [x] `npx convex dev` runs without schema errors
- [x] Reviews table created with all fields
- [x] Unique index on (jobId, reviewerId) exists
- [x] Rating field is number type (1-5 validated in mutation, not schema)

**Commit**: YES
- Message: `feat(schema): add reviews table with unique constraint`
- Files: `convex/schema.ts`
- Pre-commit: `npx convex dev --once`

---

### Task 2: Update acceptProposal for Auto In-Progress

**What to do**:
- Modify `acceptProposal` in `convex/proposals.ts`
- When creating job, set status = "in_progress" (not "pending")
- This makes job immediately active when proposal is accepted

**Must NOT do**:
- Create separate startJob mutation (automatic transition handles this)
- Change any other proposal logic

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Single line change in existing mutation
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Task 1)
- **Blocks**: Task 3
- **Blocked By**: None

**References**:
- `Patchwork_MCP/convex/proposals.ts:acceptProposal` - Find job creation call
- `Patchwork_MCP/convex/jobs.ts:createJob` - May need to update default status

**Acceptance Criteria**:
```bash
npm run test:run
# Assert: All existing tests pass
# Assert: New job created with status = "in_progress"
```

- [x] `acceptProposal` creates job with status "in_progress"
- [x] All existing proposal tests pass
- [x] Job tests updated if needed

**Commit**: YES
- Message: `feat(proposals): auto-transition job to in_progress on accept`
- Files: `convex/proposals.ts`, optionally `convex/jobs.ts`
- Pre-commit: `npm run test:run`

---

### Task 3: Create completeJob Mutation (TDD)

**What to do**:
- Write tests first in `convex/__tests__/jobs.test.ts`
- Add `completeJob` mutation to `convex/jobs.ts`:
  - Args: jobId
  - Validation: caller is seeker, job status is "in_progress"
  - Sets status = "completed", completedDate = now
- Test cases: seeker can complete, tasker cannot, wrong status rejected

**Must NOT do**:
- Allow tasker to complete job
- Allow completion of pending/completed/cancelled jobs
- Create cancelJob or disputeJob

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: TDD with authorization checks
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 4, 5)
- **Blocks**: Tasks 6, 7, 8
- **Blocked By**: Task 2

**References**:
- `Patchwork_MCP/convex/jobs.ts` - Existing job mutations
- `Patchwork_MCP/convex/__tests__/jobs.test.ts` - Existing test patterns
- `Patchwork_MCP/convex/AGENTS.md` - Mutation auth pattern

**Acceptance Criteria**:
```typescript
// Tests to write:
test("seeker can complete in_progress job");
test("tasker cannot complete job (unauthorized)");
test("cannot complete pending job");
test("cannot complete already completed job");
test("completeJob sets completedDate");
```

- [x] 5+ new tests for completeJob
- [x] Only seeker can call completeJob
- [x] Only "in_progress" jobs can be completed
- [x] Sets status = "completed" and completedDate
- [x] `npm run test:run` - All tests pass

**Commit**: YES
- Message: `feat(jobs): add completeJob mutation with TDD`
- Files: `convex/jobs.ts`, `convex/__tests__/jobs.test.ts`
- Pre-commit: `npm run test:run`

---

### Task 4: Create Review Mutations (TDD)

**What to do**:
- Write tests first in `convex/__tests__/reviews.test.ts`
- Create `convex/reviews.ts` with:
  - `createReview(jobId, rating, text)` - Submit review
    - Validation: job completed, caller is participant, not already reviewed, within 30 days, text >= 10 chars, rating 1-5
    - Updates job.seekerReviewId or job.taskerReviewId
    - Calls rating aggregation
  - `getJobReviews(jobId)` - Get reviews for a job (blind: only show if both submitted)
  - `getUserReviews(userId)` - Get all reviews for a user
  - `canReview(jobId)` - Check if current user can still review

**Must NOT do**:
- Create updateReview or deleteReview
- Add photo upload handling
- Skip 30-day validation

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Complex TDD with multiple validations and blind review logic
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 3, 5)
- **Blocks**: Tasks 5, 8
- **Blocked By**: Task 1

**References**:
- `Patchwork_MCP/convex/schema.ts` - Reviews table from Task 1
- `Patchwork_MCP/convex/jobs.ts` - Job schema with seekerReviewId/taskerReviewId
- `Patchwork_MCP/convex/AGENTS.md` - Mutation patterns

**Acceptance Criteria**:
```typescript
// Tests to write:
test("can create review for completed job");
test("cannot review non-completed job");
test("cannot review if not job participant");
test("cannot review twice");
test("cannot review after 30 days");
test("rating must be 1-5");
test("text must be 10+ chars");
test("blind review: getJobReviews returns empty until both submit");
test("blind review: getJobReviews returns both after both submit");
```

- [x] 10+ tests for review mutations
- [x] createReview validates all constraints
- [x] 30-day window enforced (from completedDate)
- [x] Blind review logic in getJobReviews
- [x] Updates job.seekerReviewId or taskerReviewId
- [x] `npm run test:run` - All tests pass

**Commit**: YES
- Message: `feat(reviews): add review mutations with blind review and TDD`
- Files: `convex/reviews.ts`, `convex/__tests__/reviews.test.ts`
- Pre-commit: `npm run test:run`

---

### Task 5: Add Rating Aggregation Logic

**What to do**:
- Update `createReview` to call rating aggregation
- Create internal `updateProfileRating` function:
  - For tasker reviews: Update `taskerProfiles.rating` and `taskerProfiles.reviewCount`
  - For seeker reviews: Update `seekerProfiles.rating` and `seekerProfiles.ratingCount`
  - Formula: `newRating = (oldRating * oldCount + rating) / (oldCount + 1)`
- Add tests for rating calculations

**Must NOT do**:
- Update category-specific ratings (taskerCategories) - defer
- Allow rating to go outside 0-5 range
- Create separate aggregation mutation (internal only)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Math logic with atomic updates
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 3, 4)
- **Blocks**: Task 8
- **Blocked By**: Task 4

**References**:
- `Patchwork_MCP/convex/reviews.ts` - createReview from Task 4
- `Patchwork_MCP/convex/schema.ts` - taskerProfiles.rating, seekerProfiles.rating
- `Patchwork_MCP/convex/taskers.ts` - Profile update patterns

**Acceptance Criteria**:
```typescript
// Tests to write:
test("first review sets profile rating to that rating");
test("second review calculates weighted average");
test("rating stays within 0-5 range");
test("reviewCount increments on each review");
```

- [x] Rating aggregation called atomically in createReview
- [x] Weighted average formula correct
- [x] Both taskerProfiles and seekerProfiles updated correctly
- [x] 4+ new tests for aggregation
- [x] `npm run test:run` - All tests pass

**Commit**: YES
- Message: `feat(reviews): add rating aggregation on review creation`
- Files: `convex/reviews.ts`
- Pre-commit: `npm run test:run`

---

### Task 6: Wire Jobs.tsx to Convex

**What to do**:
- Replace mock data in `Jobs.tsx` with `useQuery(api.jobs.listJobs)`
- Show real job list with status badges
- Handle loading and empty states
- Filter by status (in_progress, completed)

**Must NOT do**:
- Add new UI components
- Change tab structure
- Add job search/filter

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: Frontend Convex integration
- **Skills**: `["frontend-ui-ux"]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Task 7)
- **Blocks**: Task 9
- **Blocked By**: Task 3

**References**:
- `Patchwork_MCP/src/screens/Jobs.tsx` - Current mock implementation
- `Patchwork_MCP/convex/jobs.ts:listJobs` - Query to use
- `Patchwork_MCP/src/screens/Messages.tsx` - Example of Convex query integration

**Acceptance Criteria**:
- [x] Jobs.tsx imports useQuery from "convex/react"
- [x] Jobs loaded from `api.jobs.listJobs`
- [x] Loading state shown while query pending
- [x] Empty state for no jobs
- [x] Status badges reflect real job.status
- [x] TypeScript compiles: `npx tsc --noEmit`

**Commit**: YES
- Message: `feat(jobs-screen): wire Jobs.tsx to Convex`
- Files: `src/screens/Jobs.tsx`
- Pre-commit: `npx tsc --noEmit`

---

### Task 7: Wire JobDetail.tsx to Convex

**What to do**:
- Accept `jobId` prop and fetch with `useQuery(api.jobs.getJob, { jobId })`
- Display real job data
- Show "Leave Review" button if:
  - Job is completed
  - User hasn't reviewed yet
  - Within 30-day window
- Navigate to review flow when clicked

**Must NOT do**:
- Add job action buttons (Start, Cancel, Dispute)
- Change layout significantly

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: Frontend Convex integration
- **Skills**: `["frontend-ui-ux"]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Task 6)
- **Blocks**: Task 9
- **Blocked By**: Task 3

**References**:
- `Patchwork_MCP/src/screens/JobDetail.tsx` - Current mock implementation
- `Patchwork_MCP/convex/jobs.ts:getJob` - Query to use
- `Patchwork_MCP/convex/reviews.ts:canReview` - Check if can review

**Acceptance Criteria**:
- [x] JobDetail accepts jobId prop
- [x] Uses `api.jobs.getJob` query
- [x] Displays real job data
- [x] "Leave Review" button conditional on canReview
- [x] TypeScript compiles: `npx tsc --noEmit`

**Commit**: YES
- Message: `feat(job-detail): wire JobDetail.tsx to Convex`
- Files: `src/screens/JobDetail.tsx`
- Pre-commit: `npx tsc --noEmit`

---

### Task 8: Wire Chat.tsx Completion + Review Flow

**What to do**:
- Wire "Complete Job" button to `completeJob` mutation
- Only show button if: user is seeker AND job status is "in_progress"
- On completion success, show review modal
- Wire review modal submit to `createReview` mutation
- Validate text length (10+ chars) before submit
- Handle success/error states

**Must NOT do**:
- Add photo upload to review modal
- Allow empty review text
- Change modal UI design

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: Complex frontend flow with multiple mutations
- **Skills**: `["frontend-ui-ux"]`

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 3 (after Tasks 3, 4, 5)
- **Blocks**: Task 9
- **Blocked By**: Tasks 3, 4, 5

**References**:
- `Patchwork_MCP/src/screens/Chat.tsx` - Current implementation with modal
- `Patchwork_MCP/src/hooks/useChat.ts` - Add new mutations
- `Patchwork_MCP/convex/jobs.ts:completeJob` - Mutation to call
- `Patchwork_MCP/convex/reviews.ts:createReview` - Mutation to call

**Acceptance Criteria**:
- [x] "Complete Job" only visible for seeker on in_progress job
- [x] Clicking calls completeJob mutation
- [x] On success, review modal appears
- [x] Review modal validates text >= 10 chars
- [x] Submit calls createReview mutation
- [x] Success shows confirmation
- [x] Error states handled gracefully

**Commit**: YES
- Message: `feat(chat): wire job completion and review flow`
- Files: `src/screens/Chat.tsx`, `src/hooks/useChat.ts`
- Pre-commit: `npx tsc --noEmit`

---

### Task 9: E2E Verification

**What to do**:
- Create comprehensive UI test or manual verification
- Test complete flow: proposal accept → job in_progress → complete → review
- Verify blind review (review not visible until both submit)
- Verify rating aggregation updates profile
- Verify 30-day window (mock time if testing)

**Must NOT do**:
- Add features not in plan
- Skip verification steps

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: E2E verification
- **Skills**: `["playwright"]`

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 3 (final)
- **Blocks**: None
- **Blocked By**: Tasks 6, 7, 8

**References**:
- `tests/ui/smoke.test.ts` - Existing E2E pattern
- All screens from Tasks 6, 7, 8

**Acceptance Criteria**:
- [x] Job lifecycle: accept → in_progress → complete works
- [x] Review submission works
- [x] Blind review: hidden until both parties submit
- [x] Rating shows updated on profile
- [x] All backend tests pass: `npm run test:run`

**Commit**: YES
- Message: `test(e2e): verify phase 5 job lifecycle and reviews`
- Files: Test file or evidence screenshots
- Pre-commit: `npm run test:run`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(schema): add reviews table` | convex/schema.ts | npx convex dev --once |
| 2 | `feat(proposals): auto in_progress` | convex/proposals.ts | npm run test:run |
| 3 | `feat(jobs): completeJob mutation` | convex/jobs.ts, tests | npm run test:run |
| 4 | `feat(reviews): review mutations` | convex/reviews.ts, tests | npm run test:run |
| 5 | `feat(reviews): rating aggregation` | convex/reviews.ts | npm run test:run |
| 6 | `feat(jobs-screen): wire to Convex` | src/screens/Jobs.tsx | npx tsc --noEmit |
| 7 | `feat(job-detail): wire to Convex` | src/screens/JobDetail.tsx | npx tsc --noEmit |
| 8 | `feat(chat): completion + review flow` | src/screens/Chat.tsx | npx tsc --noEmit |
| 9 | `test(e2e): phase 5 verification` | tests | npm run test:run |

---

## Success Criteria

### Verification Commands
```bash
# Backend tests
npm run test:run
# Expected: 60+ tests pass (53 existing + 15+ new)

# TypeScript check
npx tsc --noEmit
# Expected: No errors

# Convex deployment
npx convex dev --once
# Expected: Schema deployed successfully
```

### Final Checklist
- [x] All "Must Have" features present
- [x] All "Must NOT Have" guardrails respected
- [x] Reviews table with unique constraint
- [x] Blind review logic working
- [x] 30-day window enforced
- [x] Rating aggregation updates profiles
- [x] Job lifecycle works end-to-end
- [x] 15+ new backend tests passing
