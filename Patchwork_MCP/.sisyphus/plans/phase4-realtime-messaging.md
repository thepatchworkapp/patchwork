# Phase 4: Real-time Messaging

## TL;DR

> **Quick Summary**: Implement real-time messaging system with Convex - conversations, text/image messages, and proposal workflow with job creation on accept.
> 
> **Deliverables**:
> - Schema expansion (conversations, messages, proposals, jobs tables)
> - Backend mutations/queries with TDD (convex-test)
> - Chat.tsx refactored with useChat hook + Convex integration
> - Messages.tsx wired to real conversation list
> - Real-time updates via Convex subscriptions
> 
> **Estimated Effort**: Large (3-5 days)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Schema → Backend Tests → Backend Implementation → Frontend Integration

---

## Context

### Original Request
Implement Phase 4 from IMPLEMENTATION_PLAN.md - Real-time Messaging with Convex, including proposals and job creation.

### Interview Summary
**Key Discussions**:
- Proposals included in Phase 4 (tightly coupled with messages)
- Text messages priority, then proposals
- Image attachments: up to 3 per message, 10MB total
- Read receipts included; typing indicators & presence deferred
- TDD approach continues (17 existing tests)
- Chat.tsx refactoring: extract useChat hook

**Research Findings**:
- Chat.tsx has 16 useState calls (still needs cleanup)
- Messages.tsx onOpenChat doesn't pass conversation ID (needs fix)
- Schema already designed in CONVEX_SCHEMA.md
- Rate type mismatch: use 'flat' consistently (update jobs schema)

### Metis Review
**Identified Gaps** (addressed):
- Rate type naming: resolved → use 'flat' everywhere
- Job creation scope: resolved → Phase 4 creates job on accept
- Conversation initiation: resolved → Seeker initiates only
- Attachment limits: resolved → 3 images, 10MB total
- System message types: defined 5 types

---

## Work Objectives

### Core Objective
Build complete real-time messaging system enabling seekers and taskers to communicate, send proposals, and create jobs when proposals are accepted.

### Concrete Deliverables
- `convex/schema.ts` - Add conversations, messages, proposals, jobs, jobRequests tables
- `convex/conversations.ts` - Start, list, get, markAsRead mutations/queries
- `convex/messages.ts` - Send (text/image), list (paginated) mutations/queries
- `convex/proposals.ts` - Send, accept, decline, counter mutations
- `convex/jobs.ts` - Create job (on proposal accept), basic queries
- `convex/__tests__/conversations.test.ts` - TDD tests
- `convex/__tests__/messages.test.ts` - TDD tests
- `convex/__tests__/proposals.test.ts` - TDD tests
- `src/hooks/useChat.ts` - Extracted chat state management
- `src/screens/Chat.tsx` - Refactored with Convex integration
- `src/screens/Messages.tsx` - Wired to real data

### Definition of Done
- [ ] All 5 new tables created with proper indexes
- [ ] 15+ new backend tests passing
- [ ] Conversations list shows real data with unread counts
- [ ] Chat shows real-time message updates
- [ ] Text messages send/receive working
- [ ] Image attachments send/receive working
- [ ] Proposal send/accept/decline/counter working
- [ ] Job created automatically when proposal accepted
- [ ] System messages auto-generated for proposal events
- [ ] Infinite scroll pagination (25 messages) working

### Must Have
- Real-time message delivery (< 1 second latency)
- Unread count updates in conversation list
- Proposal workflow complete
- Job creation on accept
- System messages for all 5 event types

### Must NOT Have (Guardrails)
- Typing indicators (deferred to future phase)
- Online presence indicators (deferred)
- Push notifications (deferred)
- Video/audio attachments
- Message editing or deletion
- Group conversations
- Message reactions/emoji

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
├── Task 1: Schema expansion (all 5 tables)
└── Task 2: Extract useChat hook skeleton (frontend prep)

Wave 2 (After Wave 1):
├── Task 3: Conversations TDD + implementation
├── Task 4: Messages TDD + implementation
└── Task 5: Proposals TDD + implementation

Wave 3 (After Wave 2):
├── Task 6: Jobs creation (on proposal accept)
├── Task 7: Wire Messages.tsx to Convex
├── Task 8: Wire Chat.tsx to Convex (using useChat)
└── Task 9: End-to-end verification

Critical Path: Task 1 → Task 3 → Task 5 → Task 6 → Task 8 → Task 9
Parallel Speedup: ~35% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 3, 4, 5 | 2 |
| 2 | None | 8 | 1 |
| 3 | 1 | 4, 7 | - |
| 4 | 1, 3 | 5, 8 | - |
| 5 | 1, 4 | 6, 8 | - |
| 6 | 5 | 8 | 7 |
| 7 | 3 | 9 | 6 |
| 8 | 2, 4, 5, 6 | 9 | - |
| 9 | 7, 8 | None | - |

---

## TODOs

### Task 1: Schema Expansion

**What to do**:
- Add `conversations` table with indexes (by_seeker, by_tasker, by_participants, by_lastMessage)
- Add `messages` table with indexes (by_conversation, by_conversation_time, by_sender)
- Add `proposals` table with indexes (by_conversation, by_sender, by_receiver, by_status)
- Add `jobs` table with indexes (by_seeker, by_tasker, by_status)
- Add `jobRequests` table (referenced by proposals/jobs)
- Fix rate type: use `v.literal("flat")` consistently (not "fixed")

**Must NOT do**:
- Add typing indicators or presence fields
- Add message editing/deletion fields
- Create migrations (Convex handles schema changes)

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Schema additions are straightforward copy from CONVEX_SCHEMA.md
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Task 2)
- **Blocks**: Tasks 3, 4, 5
- **Blocked By**: None

**References**:
- `Patchwork_MCP/CONVEX_SCHEMA.md:336-440` - Full conversations, messages, proposals schema definitions
- `Patchwork_MCP/CONVEX_SCHEMA.md:284-330` - Jobs and jobRequests schema
- `Patchwork_MCP/convex/schema.ts` - Current schema (add new tables after existing ones)
- `Patchwork_MCP/convex/AGENTS.md:Schema Conventions` - Index naming pattern (by_fieldName)

**Acceptance Criteria**:
- [ ] `npx convex dev` runs without schema errors
- [ ] Convex dashboard shows 5 new tables: conversations, messages, proposals, jobs, jobRequests
- [ ] All indexes created (verify in Convex dashboard)
- [ ] Rate type uses 'flat' in proposals AND jobs tables

**Commit**: YES
- Message: `feat(schema): add messaging tables (conversations, messages, proposals, jobs, jobRequests)`
- Files: `convex/schema.ts`
- Pre-commit: `npx convex dev --once`

---

### Task 2: Extract useChat Hook Skeleton

**What to do**:
- Create `src/hooks/useChat.ts` with TypeScript interfaces
- Define Message, Proposal, Conversation types matching Convex schema
- Create hook skeleton with placeholder state (will wire to Convex in Task 8)
- Export types for use in Chat.tsx

**Must NOT do**:
- Wire to Convex yet (that's Task 8)
- Change Chat.tsx yet (that's Task 8)
- Add typing indicator state (deferred)

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Type definitions and skeleton hook, no complex logic
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Task 1)
- **Blocks**: Task 8
- **Blocked By**: None

**References**:
- `Patchwork_MCP/src/screens/Chat.tsx:8-46` - Current Message interface and useState calls to consolidate
- `Patchwork_MCP/CONVEX_SCHEMA.md:368-396` - Messages table schema for type definition
- `Patchwork_MCP/CONVEX_SCHEMA.md:402-440` - Proposals table schema for type definition

**Acceptance Criteria**:
- [ ] File exists: `src/hooks/useChat.ts`
- [ ] Exports: `Message`, `Proposal`, `Conversation` TypeScript interfaces
- [ ] Exports: `useChat(conversationId: Id<"conversations">)` hook
- [ ] Hook returns: `{ messages, sendMessage, sendProposal, acceptProposal, declineProposal, counterProposal, isLoading }`
- [ ] TypeScript compiles: `npx tsc --noEmit`

**Commit**: YES
- Message: `feat(hooks): add useChat hook skeleton with types`
- Files: `src/hooks/useChat.ts`
- Pre-commit: `npx tsc --noEmit`

---

### Task 3: Conversations Backend (TDD)

**What to do**:
- Write tests first in `convex/__tests__/conversations.test.ts`
- Implement `convex/conversations.ts`:
  - `startConversation(taskerId, initialMessage?)` - Creates conversation + optional first message
  - `listConversations()` - Returns user's conversations with last message preview
  - `getConversation(conversationId)` - Get single conversation
  - `markAsRead(conversationId)` - Update unread count and lastReadAt
- Test unauthenticated access throws
- Test seeker can start conversation with tasker
- Test conversation lookup by participants index

**Must NOT do**:
- Allow tasker to initiate conversations (seeker only)
- Implement delete conversation
- Add typing indicator mutations

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: TDD with multiple mutations/queries, moderate complexity
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: NO (sequential in Wave 2)
- **Parallel Group**: Wave 2 (first)
- **Blocks**: Tasks 4, 7
- **Blocked By**: Task 1

**References**:
- `Patchwork_MCP/convex/AGENTS.md:Mutation Pattern` - Auth check + user lookup pattern
- `Patchwork_MCP/convex/AGENTS.md:Testing Pattern` - convex-test with modules pattern
- `Patchwork_MCP/convex/__tests__/users.test.ts` - Example test file structure
- `Patchwork_MCP/CONVEX_SCHEMA.md:336-365` - conversations table with all fields and indexes

**Acceptance Criteria**:
- [ ] Test file: `convex/__tests__/conversations.test.ts` with 6+ tests
- [ ] Tests cover: unauthenticated rejected, start conversation, list conversations, get by ID, mark as read, participant index lookup
- [ ] `npm run test:run` - All conversation tests pass
- [ ] `startConversation` creates both conversation and optional first message atomically
- [ ] `listConversations` returns conversations sorted by lastMessageAt DESC
- [ ] `markAsRead` updates correct unread count (seekerUnreadCount or taskerUnreadCount)

**Commit**: YES
- Message: `feat(conversations): add TDD tests and mutations for conversation management`
- Files: `convex/conversations.ts`, `convex/__tests__/conversations.test.ts`
- Pre-commit: `npm run test:run`

---

### Task 4: Messages Backend (TDD)

**What to do**:
- Write tests first in `convex/__tests__/messages.test.ts`
- Implement `convex/messages.ts`:
  - `sendMessage(conversationId, content, attachments?)` - Send text or image message
  - `listMessages(conversationId, limit?, cursor?)` - Paginated messages (25 per page)
  - `sendSystemMessage(conversationId, systemType)` - Internal function for system messages
- Handle image attachments (validate: max 3, use existing file storage)
- Update conversation's lastMessageAt, lastMessagePreview, unread counts

**Must NOT do**:
- Implement message editing or deletion
- Support video/audio attachments
- Add reactions/emoji

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: TDD with pagination logic and attachment handling
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: NO (after Task 3)
- **Parallel Group**: Wave 2 (second)
- **Blocks**: Tasks 5, 8
- **Blocked By**: Tasks 1, 3

**References**:
- `Patchwork_MCP/convex/files.ts` - Existing file upload pattern (generateUploadUrl, getUrl)
- `Patchwork_MCP/CONVEX_SCHEMA.md:368-396` - messages table with all fields
- `Patchwork_MCP/convex/__tests__/taskers.test.ts` - Example of testing with file storage
- `Patchwork_MCP/convex/AGENTS.md:Query Pattern` - Pagination pattern with cursor

**Acceptance Criteria**:
- [ ] Test file: `convex/__tests__/messages.test.ts` with 8+ tests
- [ ] Tests cover: send text, send with attachments (1-3 images), list paginated, cursor pagination, system message types, attachment limit validation
- [ ] `npm run test:run` - All message tests pass
- [ ] `sendMessage` updates conversation.lastMessageAt, lastMessagePreview, lastMessageSenderId
- [ ] `sendMessage` increments unread count for recipient (not sender)
- [ ] `listMessages` returns newest 25 messages, cursor for older
- [ ] Attachments limited to 3 max (throws if > 3)

**Commit**: YES
- Message: `feat(messages): add TDD tests and mutations for messaging with attachments`
- Files: `convex/messages.ts`, `convex/__tests__/messages.test.ts`
- Pre-commit: `npm run test:run`

---

### Task 5: Proposals Backend (TDD)

**What to do**:
- Write tests first in `convex/__tests__/proposals.test.ts`
- Implement `convex/proposals.ts`:
  - `sendProposal(conversationId, rate, rateType, startDateTime, notes?)` - Create proposal + system message
  - `acceptProposal(proposalId)` - Mark accepted + system message + trigger job creation
  - `declineProposal(proposalId)` - Mark declined + system message
  - `counterProposal(proposalId, rate, rateType, startDateTime, notes?)` - Create counter + link to previous
- System messages auto-generated for each action
- Only proposal receiver can accept/decline

**Must NOT do**:
- Allow sender to accept their own proposal
- Allow countering an already-accepted proposal
- Set proposal expiration (future feature)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Complex state machine with authorization checks
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: NO (after Task 4)
- **Parallel Group**: Wave 2 (third)
- **Blocks**: Tasks 6, 8
- **Blocked By**: Tasks 1, 4

**References**:
- `Patchwork_MCP/CONVEX_SCHEMA.md:402-440` - proposals table with status enum and counter chain
- `Patchwork_MCP/src/screens/Chat.tsx:48-129` - Frontend proposal handlers (logic to replicate in backend)
- `Patchwork_MCP/.sisyphus/drafts/phase4-realtime-messaging.md:System Message Types` - 5 system message types

**Acceptance Criteria**:
- [ ] Test file: `convex/__tests__/proposals.test.ts` with 10+ tests
- [ ] Tests cover: send proposal, accept (receiver only), decline (receiver only), counter, counter chain, system message generation, status transitions
- [ ] `npm run test:run` - All proposal tests pass
- [ ] `sendProposal` creates proposal + "proposal_sent" system message
- [ ] `acceptProposal` updates status + "proposal_accepted" system message + calls job creation
- [ ] `declineProposal` updates status + "proposal_declined" system message
- [ ] `counterProposal` creates new proposal linked to previous + "proposal_countered" system message
- [ ] Only receiver can accept/decline (sender gets error)

**Commit**: YES
- Message: `feat(proposals): add TDD tests and mutations for proposal workflow`
- Files: `convex/proposals.ts`, `convex/__tests__/proposals.test.ts`
- Pre-commit: `npm run test:run`

---

### Task 6: Jobs Creation on Proposal Accept

**What to do**:
- Create `convex/jobs.ts`:
  - `createJob(proposalId)` - Internal mutation called by acceptProposal
  - `getJob(jobId)` - Query job details
  - `listJobs(status?)` - List user's jobs (as seeker or tasker)
- Write tests in `convex/__tests__/jobs.test.ts`
- Job created with status "pending" from proposal data
- Link job to conversation

**Must NOT do**:
- Implement job status transitions (in_progress, completed) - that's Phase 5
- Implement job completion flow
- Add reviews - Phase 5

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Simpler than proposals, mostly data copying
- **Skills**: `[]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Task 7)
- **Blocks**: Task 8
- **Blocked By**: Task 5

**References**:
- `Patchwork_MCP/CONVEX_SCHEMA.md:284-330` - jobs table schema
- `Patchwork_MCP/convex/proposals.ts` - acceptProposal calls createJob internally

**Acceptance Criteria**:
- [ ] Test file: `convex/__tests__/jobs.test.ts` with 4+ tests
- [ ] Tests cover: job creation from proposal, get job, list jobs by status, list jobs by role
- [ ] `npm run test:run` - All job tests pass
- [ ] Job created with: seekerId, taskerId, proposalId, categoryId, rate, rateType, startDate, status="pending"
- [ ] Conversation.jobId updated to link to new job
- [ ] "proposal_accepted" system message mentions job creation

**Commit**: YES
- Message: `feat(jobs): add job creation on proposal accept with TDD`
- Files: `convex/jobs.ts`, `convex/__tests__/jobs.test.ts`
- Pre-commit: `npm run test:run`

---

### Task 7: Wire Messages.tsx to Convex

**What to do**:
- Replace mock `seekerConversations` and `taskerConversations` with `useQuery(api.conversations.listConversations)`
- Pass `conversationId` to `onOpenChat` callback
- Update App.tsx to handle conversationId in navigation
- Show real unread badges from conversation data
- Handle loading state while conversations load

**Must NOT do**:
- Implement conversation search (non-functional in mockup)
- Change tab UI or upsell modal
- Add new UI elements

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: Frontend integration with data binding
- **Skills**: `["frontend-ui-ux"]`

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Task 6)
- **Blocks**: Task 9
- **Blocked By**: Task 3

**References**:
- `Patchwork_MCP/src/screens/Messages.tsx` - Current implementation with mock data
- `Patchwork_MCP/src/screens/AGENTS.md:Navigation Patterns` - Callback navigation pattern
- `Patchwork_MCP/src/App.tsx` - Screen state machine, needs to pass conversationId

**Acceptance Criteria**:
- [ ] Messages.tsx imports `useQuery` from "convex/react"
- [ ] Conversations loaded from `api.conversations.listConversations`
- [ ] Loading state shown while query pending
- [ ] Empty state shown if no conversations
- [ ] `onOpenChat(conversationId)` passes ID to parent
- [ ] App.tsx updated to track `activeConversationId` state
- [ ] Unread badges show real counts from backend

**Automated Verification:**
```
# Agent executes via playwright browser automation:
1. Navigate to: http://localhost:5173
2. Login as test user
3. Navigate to Messages screen
4. Wait for: conversation list to load (no "Loading..." text)
5. Assert: at least one conversation visible OR empty state
6. Click: first conversation
7. Assert: navigates to Chat screen
8. Screenshot: .sisyphus/evidence/task-7-messages-wired.png
```

**Commit**: YES
- Message: `feat(messages-screen): wire Messages.tsx to Convex conversations`
- Files: `src/screens/Messages.tsx`, `src/App.tsx`
- Pre-commit: `npx tsc --noEmit`

---

### Task 8: Wire Chat.tsx to Convex with useChat Hook

**What to do**:
- Complete `useChat` hook implementation:
  - `useQuery(api.messages.listMessages)` for real-time messages
  - `useMutation` for sendMessage, sendProposal, acceptProposal, declineProposal, counterProposal
  - Handle pagination (load more on scroll up)
- Refactor Chat.tsx to use `useChat` hook
- Remove mock message data
- Connect proposal modals to real mutations
- Show loading states

**Must NOT do**:
- Change modal UI design
- Add typing indicators
- Implement job completion flow (just job creation)

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: Major refactoring + Convex integration
- **Skills**: `["frontend-ui-ux"]`

**Parallelization**:
- **Can Run In Parallel**: NO (final frontend task)
- **Parallel Group**: Wave 3 (after Tasks 6, 7)
- **Blocks**: Task 9
- **Blocked By**: Tasks 2, 4, 5, 6

**References**:
- `Patchwork_MCP/src/hooks/useChat.ts` - Hook skeleton from Task 2
- `Patchwork_MCP/src/screens/Chat.tsx` - Current 16 useState to consolidate
- `Patchwork_MCP/src/screens/AGENTS.md:Modal Pattern` - Fixed overlay modal pattern
- `Patchwork_MCP/convex/AGENTS.md:File Storage Pattern` - For image attachments

**Acceptance Criteria**:
- [ ] Chat.tsx imports and uses `useChat(conversationId)` hook
- [ ] useState count reduced from 16 to < 6 (modal visibility only)
- [ ] Messages load from Convex in real-time
- [ ] Sending text message appears instantly (optimistic update optional)
- [ ] Sending proposal creates proposal message
- [ ] Accept/Decline/Counter work and show system messages
- [ ] Image attachment upload working (up to 3 images)
- [ ] Scroll up loads older messages (pagination)

**Automated Verification:**
```
# Agent executes via playwright browser automation:
1. Navigate to: http://localhost:5173
2. Login as test seeker
3. Navigate to Messages → Open conversation with tasker
4. Wait for: messages to load
5. Type in input: "Hello from test"
6. Click: send button
7. Wait for: new message bubble appears
8. Assert: message shows "Hello from test"
9. Screenshot: .sisyphus/evidence/task-8-chat-realtime.png
```

**Commit**: YES
- Message: `feat(chat): refactor Chat.tsx with useChat hook and Convex integration`
- Files: `src/hooks/useChat.ts`, `src/screens/Chat.tsx`
- Pre-commit: `npx tsc --noEmit && npm run test:run`

---

### Task 9: End-to-End Verification

**What to do**:
- Create comprehensive UI test in `tests/ui/messaging.test.ts`
- Test complete flow: start conversation → send messages → send proposal → accept → job created
- Verify real-time: open same conversation in two browser contexts
- Verify pagination: send 30+ messages, scroll up to load more

**Must NOT do**:
- Add features not in plan
- Skip any verification step

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: Browser-based E2E testing
- **Skills**: `["playwright"]` or `["dev-browser"]`
  - Note: Existing tests use agent-browser pattern; either approach works

**Parallelization**:
- **Can Run In Parallel**: NO (final verification)
- **Parallel Group**: Wave 3 (last)
- **Blocks**: None
- **Blocked By**: Tasks 7, 8

**References**:
- `Patchwork_MCP/tests/ui/tasker-onboarding.test.ts` - Existing UI test pattern
- `Patchwork_MCP/src/screens/Chat.tsx` - Chat UI for selectors
- `Patchwork_MCP/src/screens/Messages.tsx` - Messages UI for selectors

**Acceptance Criteria**:
- [ ] UI test file: `tests/ui/messaging.test.ts`
- [ ] Test: Seeker can start conversation with tasker
- [ ] Test: Messages appear in real-time (both sides)
- [ ] Test: Proposal workflow (send → accept → job created)
- [ ] Test: Image attachment sends successfully
- [ ] Test: Pagination loads older messages
- [ ] Test: Unread counts update correctly
- [ ] All tests pass: verified via playwright

**Automated Verification:**
```bash
# Agent runs:
npx playwright test tests/ui/messaging.test.ts
# Assert: All tests pass (0 failures)
```

**Commit**: YES
- Message: `test(e2e): add comprehensive messaging flow tests`
- Files: `tests/ui/messaging.test.ts`
- Pre-commit: `npx playwright test tests/ui/messaging.test.ts`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(schema): add messaging tables` | convex/schema.ts | npx convex dev --once |
| 2 | `feat(hooks): add useChat hook skeleton` | src/hooks/useChat.ts | npx tsc --noEmit |
| 3 | `feat(conversations): TDD mutations` | convex/conversations.ts, convex/__tests__/conversations.test.ts | npm run test:run |
| 4 | `feat(messages): TDD mutations` | convex/messages.ts, convex/__tests__/messages.test.ts | npm run test:run |
| 5 | `feat(proposals): TDD mutations` | convex/proposals.ts, convex/__tests__/proposals.test.ts | npm run test:run |
| 6 | `feat(jobs): job creation on accept` | convex/jobs.ts, convex/__tests__/jobs.test.ts | npm run test:run |
| 7 | `feat(messages-screen): wire to Convex` | src/screens/Messages.tsx, src/App.tsx | npx tsc --noEmit |
| 8 | `feat(chat): useChat hook + Convex` | src/hooks/useChat.ts, src/screens/Chat.tsx | npm run test:run |
| 9 | `test(e2e): messaging flow tests` | tests/ui/messaging.test.ts | npx playwright test |

---

## Success Criteria

### Verification Commands
```bash
# Backend tests
npm run test:run
# Expected: 30+ tests pass (17 existing + 15+ new)

# TypeScript check
npx tsc --noEmit
# Expected: No errors

# Convex deployment
npx convex dev --once
# Expected: Schema deployed successfully

# E2E tests
npx playwright test tests/ui/messaging.test.ts
# Expected: All tests pass
```

### Final Checklist
- [ ] All "Must Have" features present and working
- [ ] All "Must NOT Have" guardrails respected
- [ ] 30+ backend tests passing
- [ ] E2E messaging tests passing
- [ ] Real-time updates verified
- [ ] Chat.tsx useState count reduced to < 6
