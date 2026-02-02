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
