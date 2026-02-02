# Phase 5 - Job Lifecycle + Reviews - Learnings & Conventions

## Project Conventions

### Job Lifecycle
- Status flow: `pending` → `in_progress` (auto on proposal accept) → `completed` (seeker triggers)
- Only seeker can mark job complete
- No cancel/dispute mutations in this phase

### Reviews
- Bidirectional: seeker reviews tasker AND tasker reviews seeker
- Blind: hidden until both parties submit
- 30-day window from completedDate
- Text required: 10+ characters
- Rating: 1-5 scale
- Immutable: no editing after submission
- Unique per (jobId, reviewerId) via database constraint

### Rating Aggregation
- Formula: `newRating = (oldRating * oldCount + newRating) / (oldCount + 1)`
- Updates: taskerProfiles.rating/reviewCount OR seekerProfiles.rating/ratingCount
- Atomic: happens in same transaction as review creation

## Key Files
- `convex/schema.ts` - Add reviews table
- `convex/jobs.ts` - Add completeJob mutation
- `convex/proposals.ts` - Update acceptProposal for auto in_progress
- `convex/reviews.ts` - New file for review mutations
- `convex/__tests__/reviews.test.ts` - TDD tests
- `src/screens/Jobs.tsx` - Wire to real data
- `src/screens/JobDetail.tsx` - Wire to real data
- `src/screens/Chat.tsx` - Wire completion + review flow

## Deferred (Not in Scope)
- cancelJob mutation
- disputeJob mutation
- Photo uploads in reviews
- Review editing/deletion
- Category-specific rating updates
- Public review pages

## Task 2: Reviews Mutations (COMPLETED)

### Implementation
- **File Created**: `convex/reviews.ts` with 4 mutations/queries:
  - `createReview(jobId, rating, text)` - Submit review with full validations
  - `getJobReviews(jobId)` - Blind review logic (empty until both submit)
  - `getUserReviews(userId)` - Get all reviews for user as reviewee
  - `canReview(jobId)` - Check eligibility without throwing errors

### Test Coverage (13 tests)
- ✓ Can create review for completed job
- ✓ Cannot review non-completed job
- ✓ Cannot review if not participant
- ✓ Cannot review twice
- ✓ Cannot review after 30 days
- ✓ Rating must be 1-5
- ✓ Text must be 10+ chars
- ✓ Blind review: empty until both submit
- ✓ Blind review: both visible after both submit
- ✓ canReview returns true when eligible
- ✓ canReview returns false when already reviewed
- ✓ canReview returns false after 30 days
- ✓ getUserReviews returns all reviews for user

### Key Validations
1. Job must be completed
2. Caller must be participant (seeker or tasker)
3. Caller must not have already reviewed
4. Within 30 days of completedDate
5. Rating 1-5
6. Text 10+ characters

### Blind Review Logic
- `getJobReviews` checks both `job.seekerReviewId` AND `job.taskerReviewId`
- Returns empty array until BOTH are set
- Returns both reviews once both submitted

### Database Updates
- Review inserted with jobId, reviewerId, revieweeId, rating, text, createdAt
- Job patched with seekerReviewId or taskerReviewId
- Unique index on (jobId, reviewerId) prevents duplicates at DB level

### 30-Day Window Calculation
```typescript
const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;
const completedTime = new Date(job.completedDate).getTime();
const timeSinceCompletion = Date.now() - completedTime;
if (timeSinceCompletion > THIRTY_DAYS_MS) {
  throw new Error("Review window expired");
}
```

### Error Messages (Clear and Specific)
- "Job must be completed"
- "Not a participant in this job"
- "Already reviewed"
- "Review window expired"
- "Rating must be between 1 and 5"
- "Review text must be at least 10 characters"

### Testing Pattern (TDD)
- Created test file first with 13 test cases
- Implemented mutations to satisfy tests
- All tests pass on first run
- Used helper function `createCompletedJob` to reduce duplication

## Task 3: completeJob Mutation (Wave 2)

### Implementation Pattern
- **Mutation structure**: Auth check → User lookup → Job fetch → Permission validation → Status validation → Patch operation
- **Auth**: Only seeker can complete (check `job.seekerId === user._id`)
- **Status guard**: Only `in_progress` jobs can be completed
- **Field updates**: Set `status = "completed"`, `completedDate = ISO string`, `updatedAt = timestamp`

### Schema Convention Discovery
- `completedDate` field type: `v.optional(v.string())` not `v.number()`
- Use `new Date().toISOString()` for date fields typed as strings
- Use `Date.now()` for timestamp fields typed as numbers
- Check schema before assuming timestamp field types

### Test Patterns
- TDD approach: Write 5 tests first, then implement
- Test coverage: Success case, unauthorized actor, invalid status transitions, duplicate operations, field verification
- String date comparison: Use `>=` and `<=` operators for ISO date strings
- Type verification: Use `typeof` checks instead of numeric comparisons for string fields

### Gotchas
- TypeScript LSP may lag after `convex codegen` - types regenerate but LSP cache persists
- Runtime tests pass before LSP errors clear
- BetterAuthError in test output is pre-existing, unrelated to job mutations

## Wave 2 Task 5 - Rating Aggregation (Completed)

### Implementation Details
- Created `convex/reviews.ts` with `createReview` mutation
- Added internal `updateProfileRating` function for atomic rating updates
- Handles both tasker and seeker profile updates
- Uses weighted average formula: `(oldRating * oldCount + newRating) / (oldCount + 1)`
- Properly handles first review case (oldCount = 0)
- Different field names: taskerProfiles.reviewCount vs seekerProfiles.ratingCount
- Rating clamped to 0-5 range for safety

### Tests Added (11 total)
**Rating Aggregation Tests:**
1. first review sets profile rating to that rating ✓
2. second review calculates weighted average ✓
3. rating stays within 0-5 range ✓
4. reviewCount increments on each review ✓
5. tasker reviewing seeker updates seekerProfiles.ratingCount ✓
6. multiple reviews create correct weighted average ✓

**Basic Functionality Tests:**
7. can create review for completed job ✓
8. cannot review non-completed job ✓
9. cannot review twice ✓
10. rating must be 1-5 ✓
11. text must be 10+ chars ✓

### Key Findings
- updateProfileRating must determine correct table: taskerProfiles (for taskers) or seekerProfiles (for seekers)
- Field name inconsistency: reviewCount vs ratingCount must be handled
- Rating aggregation happens atomically in same transaction as review creation
- Seeker reviewing tasker → updates taskerProfiles.rating/reviewCount
- Tasker reviewing seeker → updates seekerProfiles.rating/ratingCount
- Formula works correctly for first review: (0 * 0 + rating) / (0 + 1) = rating
- All 67 backend tests pass (8 test files)

### Files Modified
- `convex/reviews.ts` - Created with full review CRUD + rating aggregation
- `convex/__tests__/reviews.test.ts` - Created with 11 comprehensive tests

## Wave 3 Task 6 - Wire Jobs.tsx (Completed)

### Implementation
- Wired `Jobs.tsx` to real Convex data using `useQuery(api.jobs.listJobs)`.
- Implemented client-side filtering for job tabs ("in-progress" vs "completed") as requested.
- Added loading state (spinner) and empty states.
- Mapped schema fields:
  - `job.description` used for notes display
  - `job.rate` and `job.rateType` ("hourly"/"flat")
  - `job.startDate` (ISO string) formatted with `toLocaleDateString()`
  - Tasker name placeholder ("Tasker") used until profile lookup is added

### Learnings
- `tsconfig.json` appears to be missing in the project root, but `vite build` succeeds.
- Convex `jobs` schema uses `description` for the job description (from proposal notes), and `notes` is a separate optional field.
- `listJobs` query supports status filtering, but client-side filtering was used per specific instructions.

## JobDetail Wiring
- Wired `JobDetail.tsx` to `api.jobs.getJob` and `api.reviews.canReview`.
- Updated `App.tsx` to track `activeJobId` and pass it to `JobDetail`.
- Updated `Jobs.tsx` to trigger navigation on click with `onOpenJob`.
- Note: `typescript` is not listed in dependencies, so `tsc` is unavailable. Build verification relies on `vite build`.
- Note: `jobs` schema lacks location data, so Location card was removed from `JobDetail`.
