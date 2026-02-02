# Phase 4 - Realtime Messaging: Schema Expansion

## Task 1: Schema Expansion ✅ COMPLETED

### Date: 2026-02-01

### Changes Made
- Added 5 new tables to `Patchwork_MCP/convex/schema.ts`:
  1. **conversations** - Tracks conversations between seekers and taskers
     - 6 indexes: by_seeker, by_tasker, by_participants, by_lastMessage, by_seeker_lastMessage, by_tasker_lastMessage
  2. **messages** - Individual messages within conversations
     - 3 indexes: by_conversation, by_conversation_time, by_sender
  3. **proposals** - Job proposals sent in conversations
     - 4 indexes: by_conversation, by_sender, by_receiver, by_status
  4. **jobs** - Accepted jobs from proposals
     - 5 indexes: by_seeker, by_tasker, by_status, by_seeker_status, by_tasker_status
  5. **jobRequests** - Job requests posted by seekers
     - 6 indexes: by_seeker, by_status, by_category, by_created, by_location, by_seeker_status

### Key Implementation Details
- All tables include `createdAt` and `updatedAt` timestamps
- Used `v.union(v.literal(...))` for all enum fields (not v.string())
- **CRITICAL FIX**: Used "flat" (not "fixed") for rateType in both proposals and jobs tables
- Proper index naming convention: `by_<fieldName>` or `by_<field1>_<field2>`
- Nested objects for complex fields (location, timing, budget)
- Optional fields properly marked with `v.optional()`

### Verification
✅ `npx convex dev --once` - Schema compiled successfully
✅ All 5 tables defined with correct fields and indexes
✅ Rate type consistency: "flat" used in proposals and jobs (line 229, 279)
✅ Existing tables (users, profiles, categories) unchanged

### Commit
- Hash: 0a7bbac
- Message: `feat(schema): add messaging tables (conversations, messages, proposals, jobs, jobRequests)`

### Blockers Resolved
- None - Task completed without blockers

### Next Steps
- Task 2: Backend mutations for messaging
- Task 3: Backend queries for messaging
- Task 4: Real-time subscriptions
- Task 5: Frontend messaging UI

### Notes
- Schema follows existing conventions from AGENTS.md
- All field definitions copied exactly from CONVEX_SCHEMA.md reference
- No migrations needed - Convex handles schema changes automatically
