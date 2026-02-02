# Phase 4 - Realtime Messaging: Proposals Backend (TDD)

## Task 5: Proposals Backend (TDD) ✅ COMPLETED

### Date: 2026-02-01

### Deliverables

- [x] Test file: `Patchwork_MCP/convex/__tests__/proposals.test.ts` with 12 tests
- [x] Implementation: `Patchwork_MCP/convex/proposals.ts` with 4 mutations
- [x] Helper: `Patchwork_MCP/convex/jobs.ts` with createJob stub
- [x] All tests pass: `npm run test:run` (48/48 tests passing across entire suite)
- [x] Commit: `feat(proposals): add TDD tests and mutations for proposal workflow`

### Implementation Details

#### Mutations

1. **sendProposal(conversationId, rate, rateType, startDateTime, notes?)**
   - Creates proposal with "pending" status
   - Determines receiver from conversation participants (opposite of sender)
   - Calls sendSystemMessage with "proposal_sent" type
   - Returns proposal ID

2. **acceptProposal(proposalId)**
   - Validates: only receiver can accept
   - Validates: proposal status must be "pending"
   - Updates proposal status to "accepted"
   - Creates job via internal mutation (createJob)
   - Calls sendSystemMessage with "proposal_accepted" type
   - Returns { jobId }

3. **declineProposal(proposalId)**
   - Validates: only receiver can decline
   - Updates proposal status to "declined"
   - Calls sendSystemMessage with "proposal_declined" type
   - Returns proposal ID

4. **counterProposal(proposalId, rate, rateType, startDateTime, notes?)**
   - Validates: only receiver can counter
   - Updates original proposal status to "countered"
   - Creates new proposal with:
     - previousProposalId = original proposal ID
     - Sender and receiver roles swapped
     - Status = "pending"
   - Updates original proposal with counterProposalId
   - Calls sendSystemMessage with "proposal_countered" type
   - Returns counter proposal ID

#### Helper: jobs.ts - createJob (Internal Mutation)

Minimal implementation for Task 5 (will be fully implemented in Task 6):
- Gets proposal data
- Looks up first available category (stub logic)
- Creates job with:
  - seekerId = proposal.receiverId
  - taskerId = proposal.senderId
  - categoryId/categoryName from database
  - Rate, rateType, startDate from proposal
  - Status = "pending"
- Updates conversation with jobId
- Returns jobId

### Test Coverage (12 tests)

1. ✅ Unauthenticated user cannot send proposal (throws "Unauthorized")
2. ✅ Can send proposal in conversation
3. ✅ Sending proposal creates "proposal_sent" system message
4. ✅ Receiver can accept proposal
5. ✅ Sender cannot accept their own proposal (throws error)
6. ✅ acceptProposal creates "proposal_accepted" system message
7. ✅ Receiver can decline proposal
8. ✅ declineProposal creates "proposal_declined" system message
9. ✅ Receiver can counter proposal
10. ✅ counterProposal creates "proposal_countered" system message
11. ✅ Cannot accept already-declined proposal (throws error)
12. ✅ Job created when proposal accepted

### TDD Process Followed

1. **RED**: Wrote 12 failing tests in `proposals.test.ts`
2. **GREEN**: Implemented minimum code in `proposals.ts` to pass all tests
3. **REFACTOR**: Fixed transaction issues (scheduler vs runMutation)
4. **VERIFY**: All tests passing (48/48 across entire suite)

### Technical Decisions

1. **System Message Integration**:
   - Changed sendSystemMessage from mutation to internalMutation
   - Uses ctx.runMutation (not ctx.scheduler) for immediate execution in tests
   - Removed auth requirement - uses conversation.seekerId as sender
   
2. **Receiver Validation**:
   - All accept/decline/counter operations check: `proposal.receiverId === user._id`
   - Throws clear error messages for unauthorized actions
   - Only receiver (not sender) can respond to proposals

3. **Counter Proposal Chain**:
   - Original proposal gets `counterProposalId` linking to counter
   - Counter proposal gets `previousProposalId` linking back
   - Roles swap: original receiver becomes counter sender
   - Both proposals maintain full history

4. **Job Creation on Accept**:
   - acceptProposal calls internal.jobs.createJob
   - createJob uses first available category (stub for Task 6)
   - Job creation updates conversation.jobId
   - Returns jobId for frontend to use

5. **Test Type Safety**:
   - Used type assertions `as Doc<"proposals">` for test verifications
   - Necessary because convex-test's `t.run()` returns union types
   - Tests verify specific fields after assertion

### Index Usage

- `by_authId` - User lookup by auth token
- `by_conversation` - List proposals for conversation
- `by_sender` - List proposals sent by user
- `by_receiver` - List proposals received by user
- `by_status` - Query proposals by status

### Verification

✅ `npm run test:run` - All 12 proposal tests passing
✅ Total test suite: 48 tests passing (users: 4, conversations: 7, categories: 5, taskers: 8, messages: 10, proposals: 12, ui: 2)
✅ No regressions in existing tests

### Blockers Resolved

- **Scheduler vs runMutation**: Initial implementation used ctx.scheduler.runAfter which caused "Write outside of transaction" errors in tests. Fixed by using ctx.runMutation for immediate execution.
- **Job creation validation**: Jobs table requires valid categoryId. Fixed by having createJob query first available category from database.
- **sendSystemMessage auth**: Changed from mutation to internalMutation to avoid auth checks when called from other mutations.

### Warnings (Non-blocking)

- **LSP TypeScript Errors**: Circular reference errors in proposals.ts related to Convex type generation (lines 55, 59, 87). These don't affect runtime or tests.
- **Test Type Assertions**: convex-test's t.run() returns union types requiring `as Doc<"table">` assertions for property access. This is expected behavior.
- **BetterAuth Warnings**: Same pre-existing "trusted origin" warnings across entire test suite (6 unhandled rejections). Does not affect test results.

### Notes for Next Tasks

- **Task 6 (Jobs Backend)**: Expand createJob with proper category handling, validation, and status management
- **Task 8 (Chat.tsx wiring)**: Wire up proposal mutations to frontend UI for send/accept/decline/counter actions
- **Future Enhancement**: Add proposal expiration logic (currently marked optional with `expiresAt` field)

### File Changes

- Created: `Patchwork_MCP/convex/__tests__/proposals.test.ts` (674 lines, 12 tests)
- Created: `Patchwork_MCP/convex/proposals.ts` (198 lines, 4 mutations)
- Created: `Patchwork_MCP/convex/jobs.ts` (34 lines, createJob stub)
- Modified: `Patchwork_MCP/convex/messages.ts` (changed sendSystemMessage to internalMutation)

### Commit Details

- Branch: (current)
- Files: 4 files changed (3 new, 1 modified)
- Tests: 12 new tests, all passing

---

# Task 6: Jobs Backend (TDD) ✅ COMPLETED

## Date: 2026-02-01

## Deliverables

- [x] Test file: `Patchwork_MCP/convex/__tests__/jobs.test.ts` with 5 tests
- [x] Implementation: Added `getJob` and `listJobs` queries to `Patchwork_MCP/convex/jobs.ts`
- [x] All tests pass: `npm run test:run` (53/53 tests passing across entire suite)
- [x] Commit: `feat(jobs): add TDD tests for job creation`

## Implementation Details

### Queries Added to jobs.ts

1. **getJob(jobId)**
   - Query to retrieve a single job by ID
   - Returns job document or null if not found
   - No auth requirement (queries can be public)

2. **listJobs(status?)**
   - Query to list jobs for authenticated user
   - Returns jobs where user is either seeker or tasker
   - Optional status filter (pending, in_progress, completed, cancelled, disputed)
   - Uses indexes: `by_seeker_status` and `by_tasker_status`
   - Combines results and deduplicates by job ID

### Test Coverage (5 tests)

1. ✅ Job created when proposal accepted (integration test)
   - Verifies job creation via acceptProposal mutation
   - Checks job has correct data: status="pending", rate, rateType, proposalId

2. ✅ getJob returns job by ID
   - Queries job by ID after creation
   - Verifies all fields: seekerId, taskerId, status, rate, rateType

3. ✅ listJobs returns jobs for authenticated user (as seeker)
   - Lists jobs where user is seeker
   - Verifies created job appears in results

4. ✅ listJobs returns jobs for authenticated user (as tasker)
   - Lists jobs where user is tasker
   - Verifies created job appears in results

5. ✅ listJobs filters by status when provided
   - Tests status filter with "pending" status
   - Verifies job appears in pending filter
   - Verifies job does NOT appear in "completed" filter

## TDD Process Followed

1. **RED**: Wrote 5 failing tests in `jobs.test.ts`
2. **GREEN**: Implemented `getJob` and `listJobs` queries in `jobs.ts`
3. **VERIFY**: All tests passing (53/53 across entire suite)

## Technical Decisions

1. **Query Pattern**:
   - Both queries follow standard Convex query pattern
   - getJob: Simple lookup by ID, returns null if not found
   - listJobs: Requires authentication, returns empty array if not authenticated

2. **listJobs Implementation**:
   - Uses two separate index queries (by_seeker_status, by_tasker_status)
   - Combines results in a Map to deduplicate by job ID
   - Handles optional status filter by checking args.status

3. **Index Usage**:
   - `by_seeker_status` - Query jobs by seeker and status
   - `by_tasker_status` - Query jobs by tasker and status
   - Enables efficient filtering without full table scans

4. **Test Structure**:
   - Follows same pattern as proposals.test.ts
   - Each test creates seeker/tasker, starts conversation, sends/accepts proposal
   - Verifies job creation and query results

## Verification

✅ `npm run test:run` - All 5 jobs tests passing
✅ Total test suite: 53 tests passing (users: 4, conversations: 7, categories: 5, taskers: 8, messages: 10, proposals: 12, jobs: 5, ui: 2)
✅ No regressions in existing tests
✅ Commit: `feat(jobs): add TDD tests for job creation` (2 files changed, 408 insertions)

## Warnings (Non-blocking)

- **BetterAuth Warnings**: Same pre-existing "trusted origin" warnings across entire test suite (7 unhandled rejections). Does not affect test results.

## Notes for Next Tasks

- **Task 7 (Job Status Updates)**: Add mutations to update job status (in_progress, completed, cancelled, disputed)
- **Task 8 (Chat.tsx wiring)**: Wire up job queries to frontend UI for displaying job details
- **Future Enhancement**: Add job completion and review workflow
