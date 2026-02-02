# Phase 6: Search & Discovery

## TL;DR

> **Quick Summary**: Wire HomeSwipe and Browse screens to real Convex data with geospatial tasker search using @convex-dev/geospatial, implementing service area overlap matching logic.
> 
> **Deliverables**:
> - `convex/search.ts` with searchTaskers query
> - `convex/location.ts` with location update mutations
> - `src/hooks/useUserLocation.ts` hook with GPS + fallback
> - HomeSwipe.tsx wired to real data
> - Browse.tsx wired to real data (list view)
> - Backend tests (TDD)
> 
> **Estimated Effort**: Medium-Large (8-12 tasks)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 → Task 2 → Task 4 → Task 6 → Task 8

---

## Context

### Original Request
Continue Phase 6: Search & Discovery from IMPLEMENTATION_PLAN.md - wire HomeSwipe and Browse screens to real Convex data with geospatial tasker search.

### Interview Summary
**Key Discussions**:
- Geospatial approach: @convex-dev/geospatial (official Convex component)
- User location capture: Browser Geolocation API with manual city fallback
- Location updates: Continuous background every 15 min, smart push (only if moved >500m)
- Match logic: SERVICE AREA OVERLAP - `distance(seeker, tasker) <= seekerRadius + taskerServiceRadius`
- Test strategy: TDD

**Research Findings**:
- `taskerProfiles.location` exists but not populated
- `taskerCategories.serviceRadius` stores per-category service radius (1-250 km)
- @convex-dev/geospatial provides `nearest()` with maxDistance filter
- Frontend expects: name, category, rating, reviews, price, distance, verified, bio, completedJobs

### Metis Review
**Identified Gaps** (addressed):
- Multi-category radius: Use category-specific serviceRadius in query
- Seeker radius source: Pass from UI slider (not stored)
- nextAvailable field: Remove from interface (not in schema)
- ghostMode filtering: Exclude ghostMode=true taskers
- No location fallback: Add city-based geocoding fallback

---

## Work Objectives

### Core Objective
Enable real tasker discovery by implementing geospatial search with service area overlap matching, replacing all mock data in HomeSwipe and Browse screens.

### Concrete Deliverables
- `convex/search.ts` - searchTaskers query with overlap logic
- `convex/location.ts` - updateUserLocation, updateTaskerLocation mutations
- `src/hooks/useUserLocation.ts` - GPS + fallback + smart update hook
- `HomeSwipe.tsx` - wired to real search results
- `Browse.tsx` - list view wired to real results
- `convex/__tests__/search.test.ts` - backend tests
- `convex/__tests__/location.test.ts` - location mutation tests

### Definition of Done
- [x] `bun test convex/__tests__/search.test.ts` passes (8 tests)
- [x] `bun test convex/__tests__/location.test.ts` passes (4 tests)
- [x] `npm run build` succeeds
- [x] HomeSwipe shows real taskers from Convex
- [x] Browse shows real taskers from Convex
- [x] Category filter works end-to-end
- [x] Radius filter works with overlap logic

### Must Have
- Search excludes ghostMode=true taskers
- Search excludes isOnboarded=false taskers
- Service area overlap matching (seeker radius + tasker radius)
- Category filtering by slug
- Distance calculation in results
- Loading and empty states in UI

### Must NOT Have (Guardrails)
- Map view implementation (keep placeholder)
- Availability/scheduling system
- Location history storage
- Tasker's exact coordinates in response (only distance)
- Saved search preferences
- Real-time location streaming

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (67 tests passing)
- **User wants tests**: TDD
- **Framework**: Vitest + convex-test

### TDD Workflow
Each TODO follows RED-GREEN-REFACTOR:
1. **RED**: Write failing test first
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Clean up while keeping green

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Install @convex-dev/geospatial + register component
└── Task 5: Create useUserLocation hook (can start independently)

Wave 2 (After Wave 1):
├── Task 2: Create location mutations (TDD)
├── Task 3: Create search query (TDD)
└── Task 6: Wire HomeSwipe.tsx

Wave 3 (After Wave 2):
├── Task 4: Add geospatial index + overlap logic
├── Task 7: Wire Browse.tsx
└── Task 8: E2E verification

Critical Path: Task 1 → Task 2 → Task 4 → Task 6 → Task 8
Parallel Speedup: ~35% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 3, 4 | 5 |
| 2 | 1 | 4, 6 | 3, 5 |
| 3 | 1 | 4, 6, 7 | 2, 5 |
| 4 | 2, 3 | 6, 7 | None |
| 5 | None | 6, 7 | 1, 2, 3 |
| 6 | 3, 4, 5 | 8 | 7 |
| 7 | 3, 4, 5 | 8 | 6 |
| 8 | 6, 7 | None | None (final) |

---

## TODOs

- [x] 1. Install and configure @convex-dev/geospatial

  **What to do**:
  - Install package: `npm install @convex-dev/geospatial`
  - Update `convex/convex.config.ts` to register the geospatial component
  - Verify installation by checking that Convex syncs without errors

  **Must NOT do**:
  - Modify schema.ts yet (that's Task 4)
  - Create any queries yet

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single package install + config file edit, straightforward
  - **Skills**: [`git-master`]
    - `git-master`: May need to commit after config change

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 5)
  - **Blocks**: Tasks 2, 3, 4
  - **Blocked By**: None

  **References**:
  - `convex/convex.config.ts:1-15` - Current Convex config with better-auth component
  - Librarian research on @convex-dev/geospatial - Installation and setup patterns
  - `package.json` - Dependencies list

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  grep "@convex-dev/geospatial" package.json
  # Assert: Returns a line showing the dependency
  
  grep "geospatial" convex/convex.config.ts
  # Assert: Returns lines showing geospatial component registration
  
  npx convex dev --once
  # Assert: Exit code 0, no errors about geospatial component
  ```

  **Commit**: YES
  - Message: `feat(convex): add @convex-dev/geospatial component`
  - Files: `package.json`, `package-lock.json`, `convex/convex.config.ts`
  - Pre-commit: `npx convex dev --once`

---

- [x] 2. Create location update mutations (TDD)

  **What to do**:
  - Create `convex/__tests__/location.test.ts` with tests FIRST:
    - Test: updateUserLocation stores coordinates
    - Test: updateUserLocation rejects if not authenticated
    - Test: updateTaskerLocation updates taskerProfiles.location
    - Test: Location update respects 500m threshold (skip if too close)
  - Create `convex/location.ts` with mutations:
    - `updateUserLocation(lat, lng, source)` - updates users.location.coordinates
    - `updateTaskerLocation(lat, lng)` - updates taskerProfiles.location
  - Add `locationUpdatedAt` field to track last update time

  **Must NOT do**:
  - Store location history (privacy)
  - Modify existing users.ts or taskers.ts mutations
  - Add geospatial indexing yet (Task 4)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: TDD backend work, requires test setup + mutation implementation
  - **Skills**: []
    - No special skills needed - standard Convex patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 5)
  - **Blocks**: Task 4
  - **Blocked By**: Task 1

  **References**:
  - `convex/schema.ts:5-32` - users table with location.coordinates field
  - `convex/schema.ts:47-97` - taskerProfiles table with location field
  - `convex/users.ts:1-100` - Existing user mutation patterns (auth check, timestamp)
  - `convex/__tests__/users.test.ts` - Test patterns with convex-test
  - `convex/AGENTS.md` - Mutation patterns (auth check first, timestamps)

  **Acceptance Criteria**:
  **TDD - RED phase:**
  - [ ] Test file created: `convex/__tests__/location.test.ts`
  - [ ] `bun test convex/__tests__/location.test.ts` → FAIL (mutations don't exist)

  **TDD - GREEN phase:**
  - [ ] `convex/location.ts` created with updateUserLocation, updateTaskerLocation
  - [ ] `bun test convex/__tests__/location.test.ts` → PASS (4 tests)

  **Automated Verification:**
  ```bash
  bun test convex/__tests__/location.test.ts
  # Assert: 4 tests passed, 0 failed
  ```

  **Commit**: YES
  - Message: `feat(convex): add location update mutations with TDD`
  - Files: `convex/location.ts`, `convex/__tests__/location.test.ts`
  - Pre-commit: `bun test convex/__tests__/location.test.ts`

---

- [x] 3. Create searchTaskers query (TDD) - Basic version

  **What to do**:
  - Create `convex/__tests__/search.test.ts` with tests FIRST:
    - Test: searchTaskers returns taskers in category
    - Test: searchTaskers excludes ghostMode=true
    - Test: searchTaskers excludes isOnboarded=false
    - Test: searchTaskers returns empty array when no matches
    - Test: searchTaskers returns formatted data (name, category, rating, etc.)
  - Create `convex/search.ts` with:
    - `searchTaskers(categorySlug, lat, lng, radiusKm)` query
    - Basic category filtering (geospatial in Task 4)
    - Return shape matching frontend interface

  **Must NOT do**:
  - Implement geospatial filtering yet (Task 4)
  - Add pagination yet
  - Return tasker's exact coordinates

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: TDD backend work with multiple test cases
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2, 5)
  - **Blocks**: Task 4
  - **Blocked By**: Task 1

  **References**:
  - `convex/schema.ts:47-130` - taskerProfiles and taskerCategories tables
  - `convex/schema.ts:132-144` - categories table with slug index
  - `convex/categories.ts` - Query patterns for category lookup
  - `convex/__tests__/proposals.test.ts` - Complex test setup patterns
  - `src/screens/HomeSwipe.tsx:30-86` - Mock tasker object shape frontend expects

  **Acceptance Criteria**:
  **TDD - RED phase:**
  - [ ] Test file created: `convex/__tests__/search.test.ts`
  - [ ] `bun test convex/__tests__/search.test.ts` → FAIL (query doesn't exist)

  **TDD - GREEN phase:**
  - [ ] `convex/search.ts` created with searchTaskers query
  - [ ] `bun test convex/__tests__/search.test.ts` → PASS (5 tests)

  **Return Shape Verification:**
  ```typescript
  // Query must return array of objects matching:
  {
    id: Id<"taskerProfiles">,
    userId: Id<"users">,
    name: string,
    category: string,
    rating: number,
    reviews: number,
    price: string,      // "$X/hr" or "$X flat"
    distance: string,   // "X.X km"
    verified: boolean,
    bio: string | null,
    completedJobs: number
  }
  ```

  **Automated Verification:**
  ```bash
  bun test convex/__tests__/search.test.ts
  # Assert: 5 tests passed, 0 failed
  ```

  **Commit**: YES
  - Message: `feat(convex): add searchTaskers query with TDD`
  - Files: `convex/search.ts`, `convex/__tests__/search.test.ts`
  - Pre-commit: `bun test convex/__tests__/search.test.ts`

---

- [x] 4. Add geospatial index + overlap logic

  **What to do**:
  - Create `convex/geospatial.ts` to initialize GeospatialIndex:
    ```typescript
    import { GeospatialIndex } from "@convex-dev/geospatial";
    import { components } from "./_generated/api";
    import { Id } from "./_generated/dataModel";
    
    export const taskerGeo = new GeospatialIndex<
      Id<"taskerProfiles">,
      { categoryId: Id<"categories"> }
    >(components.geospatial);
    ```
  - Add mutation to populate geospatial index when tasker location updates
  - Update `searchTaskers` query to:
    1. Find taskers within seekerRadius using geospatial.nearest()
    2. Post-filter for overlap: `distance <= seekerRadius + taskerServiceRadius`
    3. Calculate and return distance string

  **Must NOT do**:
  - Store exact coordinates in response
  - Implement pagination (keep simple for MVP)

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Complex geospatial logic, overlap calculation, new library integration
  - **Skills**: []
    - No special skills - deep reasoning needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (Wave 2.5)
  - **Blocks**: Tasks 6, 7
  - **Blocked By**: Tasks 2, 3

  **References**:
  - `convex/convex.config.ts` - Geospatial component registration
  - Librarian research on @convex-dev/geospatial - GeospatialIndex API, nearest() usage
  - `convex/schema.ts:117` - taskerCategories.serviceRadius field
  - `convex/search.ts` - Existing searchTaskers query to enhance

  **Acceptance Criteria**:
  - [ ] `convex/geospatial.ts` created with GeospatialIndex instance
  - [ ] `convex/location.ts` updated to populate geo index on location update
  - [ ] `convex/search.ts` enhanced with overlap logic

  **Additional Tests (add to search.test.ts):**
  - Test: Overlap logic - tasker 190km away with 200km radius + seeker 5km radius → MATCH
  - Test: No overlap - tasker 210km away with 200km radius + seeker 5km radius → NO MATCH

  **Automated Verification:**
  ```bash
  bun test convex/__tests__/search.test.ts
  # Assert: 7 tests passed (5 basic + 2 overlap tests)
  
  npx convex dev --once
  # Assert: No errors, geospatial index operational
  ```

  **Commit**: YES
  - Message: `feat(convex): add geospatial index with service area overlap logic`
  - Files: `convex/geospatial.ts`, `convex/location.ts`, `convex/search.ts`, `convex/__tests__/search.test.ts`
  - Pre-commit: `bun test convex/__tests__/search.test.ts`

---

- [x] 5. Create useUserLocation hook

  **What to do**:
  - Create `src/hooks/useUserLocation.ts` with:
    ```typescript
    interface UseUserLocationReturn {
      location: { lat: number; lng: number; source: 'gps' | 'manual' } | null;
      isLoading: boolean;
      error: string | null;
      requestLocation: () => Promise<void>;
      setManualCity: (city: string) => Promise<void>;
    }
    ```
  - Implement browser geolocation request with error handling
  - Implement 15-minute interval polling (when app is active)
  - Implement smart push: only call server if moved >500m from last update
  - Implement city fallback: show input field if GPS denied, geocode to coordinates

  **Must NOT do**:
  - Implement background location tracking (only foreground polling)
  - Store location history locally
  - Block UI while waiting for location

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: React hook with complex state management, geolocation API, intervals
  - **Skills**: []
    - Standard React patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1) - no backend dependencies for initial version
  - **Blocks**: Tasks 6, 7
  - **Blocked By**: None (can stub server calls initially)

  **References**:
  - `src/hooks/useChat.ts` - Existing hook pattern in codebase
  - `src/screens/CreateProfile.tsx:50-100` - Existing city/province selection pattern
  - MDN Geolocation API documentation

  **Acceptance Criteria**:
  - [ ] `src/hooks/useUserLocation.ts` created
  - [ ] Hook exports: location, isLoading, error, requestLocation, setManualCity
  - [ ] GPS request triggers browser permission dialog
  - [ ] Denied GPS shows city input fallback UI pattern
  - [ ] 500m threshold logic implemented (Haversine distance calculation)

  **Automated Verification (unit test pattern):**
  ```typescript
  // In a test file or manual verification:
  // 1. Hook returns isLoading=true initially
  // 2. After GPS grant, location contains lat/lng with source='gps'
  // 3. After manual city, location contains approximate coordinates with source='manual'
  // 4. Threshold check: if last=(43.65, -79.38) and new=(43.6505, -79.38) → skip update (moved <500m)
  ```

  **Commit**: YES
  - Message: `feat(hooks): add useUserLocation with GPS and city fallback`
  - Files: `src/hooks/useUserLocation.ts`
  - Pre-commit: `npm run build`

---

- [x] 6. Wire HomeSwipe.tsx to real data

  **What to do**:
  - Import useQuery, useMutation from "convex/react"
  - Import useUserLocation hook
  - Replace mock `taskers` array with:
    ```typescript
    const { location } = useUserLocation();
    const taskers = useQuery(
      api.search.searchTaskers,
      location ? {
        categorySlug: selectedCategory === "All categories" ? undefined : selectedCategory.toLowerCase(),
        lat: location.lat,
        lng: location.lng,
        radiusKm: radiusKm,
      } : "skip"
    );
    ```
  - Add loading state while taskers is undefined
  - Add empty state when taskers.length === 0
  - Update card rendering to use real data shape
  - Wire category dropdown to trigger re-query
  - Wire radius slider to trigger re-query

  **Must NOT do**:
  - Add useState for data that comes from Convex
  - Modify card swipe animation logic
  - Change visual design

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Frontend screen wiring with loading/empty states
  - **Skills**: []
    - Standard React patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 7)
  - **Blocks**: Task 8
  - **Blocked By**: Tasks 3, 4, 5

  **References**:
  - `src/screens/HomeSwipe.tsx` - Current mock implementation
  - `src/screens/Chat.tsx:1-50` - Example of Convex query integration
  - `src/screens/Jobs.tsx` - Another example of Convex wiring (just completed in Phase 5)
  - `src/screens/AGENTS.md` - Screen component patterns

  **Acceptance Criteria**:
  - [ ] Mock `taskers` array removed from HomeSwipe.tsx
  - [ ] `useQuery(api.search.searchTaskers, ...)` integrated
  - [ ] Loading spinner shows while data loads
  - [ ] Empty state shows "No taskers found in your area"
  - [ ] Category filter triggers re-query
  - [ ] Radius slider triggers re-query

  **Automated Verification (Playwright):**
  ```
  # Agent executes via playwright skill:
  1. Navigate to: http://localhost:5173
  2. Login with test user (if needed)
  3. Navigate to home (swipe) screen
  4. Wait for: loading spinner to disappear OR tasker cards to appear
  5. Assert: Either cards visible OR "No taskers" message visible
  6. Screenshot: .sisyphus/evidence/task-6-homeswipe-real-data.png
  ```

  **Commit**: YES
  - Message: `feat(ui): wire HomeSwipe to real Convex search data`
  - Files: `src/screens/HomeSwipe.tsx`
  - Pre-commit: `npm run build`

---

- [x] 7. Wire Browse.tsx to real data

  **What to do**:
  - Same pattern as Task 6 but for Browse screen
  - Replace mock `providers` array with useQuery
  - Add loading and empty states
  - Keep map view as placeholder (show "Map coming soon")
  - Wire filter/search inputs to query parameters

  **Must NOT do**:
  - Implement map view
  - Add nextAvailable field (not in schema)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Frontend screen wiring
  - **Skills**: []
    - Standard React patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 6)
  - **Blocks**: Task 8
  - **Blocked By**: Tasks 3, 4, 5

  **References**:
  - `src/screens/Browse.tsx` - Current mock implementation
  - `src/screens/HomeSwipe.tsx` - Will have same query pattern after Task 6
  - `src/screens/AGENTS.md` - Screen component patterns

  **Acceptance Criteria**:
  - [ ] Mock `providers` array removed from Browse.tsx
  - [ ] `useQuery(api.search.searchTaskers, ...)` integrated
  - [ ] Loading spinner shows while data loads
  - [ ] Empty state shows when no results
  - [ ] Map toggle shows placeholder message
  - [ ] List view displays real tasker data

  **Automated Verification (Playwright):**
  ```
  # Agent executes via playwright skill:
  1. Navigate to: http://localhost:5173
  2. Login and navigate to Browse screen
  3. Wait for: loading to complete
  4. Assert: Either tasker list visible OR "No taskers" message
  5. Click map toggle
  6. Assert: "Map coming soon" or placeholder visible
  7. Screenshot: .sisyphus/evidence/task-7-browse-real-data.png
  ```

  **Commit**: YES
  - Message: `feat(ui): wire Browse to real Convex search data`
  - Files: `src/screens/Browse.tsx`
  - Pre-commit: `npm run build`

---

- [x] 8. E2E verification and cleanup

  **What to do**:
  - Run all backend tests: `bun test`
  - Run build: `npm run build`
  - Manual verification flow:
    1. Start app with `npm run dev` + `npx convex dev`
    2. Login as test user
    3. Grant GPS permission (or use city fallback)
    4. Navigate to HomeSwipe - verify real data loads
    5. Change category filter - verify data changes
    6. Adjust radius slider - verify data changes
    7. Navigate to Browse - verify real data loads
  - Document any issues found
  - Create seed data if needed for testing

  **Must NOT do**:
  - Fix issues outside Phase 6 scope
  - Add features not in plan

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Verification tasks, no new code
  - **Skills**: [`playwright`]
    - For UI verification

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Final (after all others)
  - **Blocks**: None
  - **Blocked By**: Tasks 6, 7

  **References**:
  - All files created/modified in this phase
  - `AGENTS.md` - Testing patterns

  **Acceptance Criteria**:
  ```bash
  # All backend tests pass
  bun test
  # Assert: All tests pass (71+ tests: 67 existing + 4 location + 7 search)
  
  # Build succeeds
  npm run build
  # Assert: Exit code 0
  ```

  **E2E Verification (Playwright):**
  ```
  # Full flow test:
  1. Navigate to app
  2. Complete login flow
  3. Grant location permission
  4. Verify HomeSwipe shows taskers
  5. Change category to "Plumbing"
  6. Verify cards update
  7. Navigate to Browse
  8. Verify list shows taskers
  9. Screenshot evidence for all screens
  ```

  **Commit**: YES (if any cleanup needed)
  - Message: `chore: Phase 6 E2E verification complete`
  - Files: Any test fixes or minor adjustments
  - Pre-commit: `bun test && npm run build`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(convex): add @convex-dev/geospatial component` | package.json, convex.config.ts | npx convex dev --once |
| 2 | `feat(convex): add location update mutations with TDD` | location.ts, location.test.ts | bun test location |
| 3 | `feat(convex): add searchTaskers query with TDD` | search.ts, search.test.ts | bun test search |
| 4 | `feat(convex): add geospatial index with overlap logic` | geospatial.ts, search.ts, location.ts | bun test |
| 5 | `feat(hooks): add useUserLocation with GPS fallback` | useUserLocation.ts | npm run build |
| 6 | `feat(ui): wire HomeSwipe to real Convex search data` | HomeSwipe.tsx | npm run build |
| 7 | `feat(ui): wire Browse to real Convex search data` | Browse.tsx | npm run build |
| 8 | `chore: Phase 6 E2E verification complete` | any fixes | bun test && npm run build |

---

## Success Criteria

### Verification Commands
```bash
# All backend tests pass
bun test
# Expected: 71+ tests pass

# Build succeeds
npm run build
# Expected: Exit code 0

# Convex syncs without errors
npx convex dev --once
# Expected: No errors
```

### Final Checklist
- [x] All "Must Have" present
- [x] All "Must NOT Have" absent
- [x] All tests pass (79 including new ones)
- [x] HomeSwipe shows real data
- [x] Browse shows real data
- [x] Category filter works
- [x] Radius filter works
- [x] Overlap matching logic implemented
