
# Phase 4 - Realtime Messaging: useChat Hook

## Task 2 Completion: Extract useChat Hook Skeleton

**Status:** ✅ COMPLETED

### Deliverables

- [x] File created: `src/hooks/useChat.ts`
- [x] Exports: `Message`, `Proposal`, `Conversation` interfaces
- [x] Exports: `useChat(conversationId: Id<"conversations">)` hook
- [x] Hook returns placeholder object with all required methods
- [x] Verification: `npm run build` passes (no TypeScript errors)
- [x] Commit: `feat(hooks): add useChat hook skeleton with types`

### Implementation Details

#### Interfaces Created

1. **Message** - Matches Convex schema with fields:
   - `_id`, `conversationId`, `senderId`
   - `type`: "text" | "proposal" | "system"
   - `content`, `proposalId`, `attachments`
   - `readAt`, `createdAt`, `updatedAt`

2. **Proposal** - Matches Convex schema with fields:
   - `_id`, `conversationId`, `senderId`, `receiverId`
   - `rate` (in cents), `rateType` ("hourly" | "flat")
   - `startDateTime` (ISO format), `notes`
   - `status`: "pending" | "accepted" | "declined" | "countered" | "expired"
   - Counter proposal chain: `previousProposalId`, `counterProposalId`
   - Timestamps: `createdAt`, `updatedAt`, `expiresAt`

3. **Conversation** - Matches Convex schema with fields:
   - `_id`, `seekerId`, `taskerId`
   - `jobRequestId`, `jobId` (optional)
   - Message tracking: `lastMessageAt`, `lastMessageId`, `lastMessagePreview`, `lastMessageSenderId`
   - Unread counts: `seekerUnreadCount`, `taskerUnreadCount`
   - Read tracking: `seekerLastReadAt`, `taskerLastReadAt`
   - Timestamps: `createdAt`, `updatedAt`

#### Hook Implementation

`useChat(conversationId)` returns `UseChatReturn` with:
- **State**: `messages[]`, `isLoading`, `hasMoreMessages`
- **Actions** (placeholder implementations with console.log):
  - `sendMessage(content, attachments?)`
  - `sendProposal(rate, rateType, startDateTime, notes?)`
  - `acceptProposal(proposalId)`
  - `declineProposal(proposalId)`
  - `counterProposal(proposalId, rate, rateType, startDateTime, notes?)`
  - `loadMoreMessages()`

### Type Safety

- All types use `Id<"table">` from Convex for type-safe references
- Union types for enums (status, type, rateType)
- Optional fields marked with `?`
- Timestamps as `number` (milliseconds)

### Import Path

- Uses relative import: `import { Id } from "../../convex/_generated/dataModel"`
- Matches pattern used in other screens (TaskerOnboarding2, Profile, CreateProfile)

### Verification

- ✅ Build passes: `npm run build` (1787 modules transformed)
- ✅ No TypeScript errors
- ✅ All interfaces properly exported
- ✅ Hook signature matches specification

### Dependencies & Blocking

- **Blocks**: Task 8 (Chat.tsx integration)
- **No dependencies**: Can run in parallel with Task 1
- **Deferred**: Convex wiring (Task 8), typing indicators (future feature)

### Notes for Task 8

All action methods have TODO comments marking where Convex mutations/queries will be wired:
- `sendMessage` → Convex mutation
- `sendProposal` → Convex mutation
- `acceptProposal` → Convex mutation
- `declineProposal` → Convex mutation
- `counterProposal` → Convex mutation
- `loadMoreMessages` → Convex query

This skeleton prevents accidental implementation and clearly marks integration points.

---

# Task 8: Wire Chat.tsx to Convex with useChat Hook

**Status:** ✅ COMPLETED

### Date: 2026-02-02

### Deliverables

- [x] Implementation: `src/hooks/useChat.ts` fully wired to Convex
- [x] Implementation: `src/screens/Chat.tsx` refactored to use `useChat`
- [x] Backend Enhancement: `convex/messages.ts` and `convex/proposals.ts` updated to support linked proposal messages
- [x] Verification: `npm run build` passes
- [x] State Management: `Chat.tsx` useState count reduced from 16 to 4
- [x] Commit: `feat(chat): refactor Chat.tsx with useChat hook and Convex integration`

### Implementation Details

#### useChat Hook
- **Pagination**: Uses `usePaginatedQuery` with `api.messages.listMessages`.
- **Mutations**: 
  - `sendMessage` (text)
  - `sendProposal` (creates proposal + proposal message)
  - `acceptProposal` / `declineProposal` (updates status)
  - `counterProposal` (creates new proposal + proposal message)
- **Data**: Returns `messages` array enriched with proposal data (via backend enrichment).

#### Chat.tsx Refactoring
- Removed 12 local state variables (mock data, individual form fields).
- Consolidated modal states into `modals` object.
- Consolidated proposal form state into `proposalForm` object.
- Replaced mock message rendering with real data rendering.
- Implemented "Load older messages" button using `hasMoreMessages` and `loadMoreMessages`.
- Wired all buttons (Send, Propose, Accept, Decline, Counter) to hook functions.

#### Backend Enhancements
To support the UI requirement of displaying proposal cards within the message stream:
1. **convex/messages.ts**:
   - Added `sendProposalMessage` internal mutation to create messages with `type: "proposal"` and `proposalId`.
   - Updated `listMessages` query to fetch and attach `proposal` data for each message with `proposalId` (server-side join).
2. **convex/proposals.ts**:
   - Updated `sendProposal` and `counterProposal` to use `internal.messages.sendProposalMessage` instead of `sendSystemMessage`.
   - This ensures proposals appear as interactive cards in the chat, not just system text.

### Verification

- ✅ `npm run build` passes (1788 modules transformed).
- ✅ Type safety maintained with Convex generated types.
- ✅ Frontend logic matches backend schema.

### Notes for Future Tasks
- **Phase 5**: `handleCompleteJob` is currently a placeholder updating local modal state. It will need to be wired to a job completion mutation.
- **Reviews**: Review submission is currently a placeholder.
