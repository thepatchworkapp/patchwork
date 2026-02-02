# Phase 6: Search & Discovery - Learnings

## Task Progress

### Task 2: Location Update Mutations (TDD)
- Status: ✅ Complete
- Started: 2026-02-02
- Completed: 2026-02-02
- Commit: 72c451b4

#### Implementation Summary
Created location update mutations with strict TDD approach:
- **RED Phase**: Wrote 4 tests first, confirmed failures
- **GREEN Phase**: Implemented mutations to pass all tests

#### Files Created
- `convex/location.ts` - Location update mutations (139 lines)
- `convex/__tests__/location.test.ts` - Test suite (160 lines)

#### Mutations Implemented
1. **updateUserLocation(lat, lng, source)**
   - Updates `users.location.coordinates`
   - Implements 500m threshold (skips if moved < 500m)
   - Tracks `updatedAt` timestamp
   - Auth required

2. **updateTaskerLocation(lat, lng)**
   - Updates `taskerProfiles.location`
   - Implements 500m threshold
   - Tracks `updatedAt` timestamp
   - Auth required

#### Tests (All Passing)
1. ✅ updateUserLocation stores coordinates
2. ✅ updateUserLocation rejects if not authenticated
3. ✅ updateTaskerLocation updates taskerProfiles.location
4. ✅ Location update respects 500m threshold (skip if too close)

#### Technical Details

**Haversine Distance Formula**
Implemented accurate distance calculation between coordinates:
```typescript
const R = 6371e3; // Earth radius in meters
const φ1 = (lat1 * Math.PI) / 180;
const φ2 = (lat2 * Math.PI) / 180;
const Δφ = ((lat2 - lat1) * Math.PI) / 180;
const Δλ = ((lng2 - lng1) * Math.PI) / 180;
const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
         Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ/2) * Math.sin(Δλ/2);
const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
return R * c; // distance in meters
```

**500m Threshold Logic**
- Calculates distance from current to new coordinates
- Returns `{ updated: false, reason: "threshold", distance }` if < 500m
- Returns `{ updated: true, distance }` if >= 500m or no previous location

#### Patterns Followed
- ✅ Auth check first (identity.tokenIdentifier lookup)
- ✅ User lookup via `by_authId` index
- ✅ Timestamps on update (`updatedAt`)
- ✅ Error handling (Unauthorized, User not found, Tasker profile not found)
- ✅ convex-test module mapping pattern
- ✅ Test isolation (unique identities per test)

#### Test Learnings

**Module Mapping Required**
convex-test requires explicit module mapping:
```typescript
const modules: Record<string, () => Promise<any>> = {
  "../location.ts": async () => locationModule,
  // ... all related modules
};
```

**Test Data Setup**
For tasker location test, must:
1. Create user profile
2. Seed categories
3. Create tasker profile with all required args (categoryId, categoryBio, rateType, hourlyRate/fixedRate, serviceRadius)

**Threshold Test Strategy**
- Set initial location
- Attempt update < 500m (expect no change, same timestamp)
- Attempt update > 500m (expect change, new timestamp)
- Used ~111m per 0.001° latitude for calculations

#### Dependencies
- ✅ Schema already has `location.coordinates` in users table
- ✅ Schema already has `location` in taskerProfiles table
- No schema changes required

#### Blocks
- Task 4: Geospatial search (needs location mutations to search by proximity)

#### Next Steps
- Task 3: Ghost mode toggle
- Task 4: Geospatial search with @get-convex/geospatial
- Task 5: Premium PIN search

### Task 5: useUserLocation Hook
- Status: Completed
- Completed: 2026-02-02 08:48
- File: `Patchwork_MCP/src/hooks/useUserLocation.ts`
- Backend: `Patchwork_MCP/convex/users.ts::updateLocation`

**Implementation Details:**
- Created custom React hook with GPS and city fallback
- Followed useChat.ts pattern: useState, useCallback, useEffect
- Browser geolocation API integration via navigator.geolocation
- 15-minute polling interval using setInterval (900000ms)
- Smart push with 500m threshold using Haversine formula
- City geocoding via Nominatim/OpenStreetMap API
- Comprehensive error handling for all geolocation error codes:
  - PERMISSION_DENIED (code 1): Prompts for city fallback
  - POSITION_UNAVAILABLE (code 2): Suggests retry or city input
  - TIMEOUT (code 3): Suggests retry
- Backend mutation created: `updateLocation(lat, lng, source)`
- Updates user location coordinates and enables locationEnabled setting

**Hook Interface:**
```typescript
interface UseUserLocationReturn {
  location: { lat: number; lng: number; source: 'gps' | 'manual' } | null;
  isLoading: boolean;
  error: string | null;
  requestLocation: () => Promise<void>;
  setManualCity: (city: string) => Promise<void>;
}
```

**Verification:**
- Build successful: `npm run build` ✓
- No TypeScript errors ✓
- LSP diagnostics clean ✓
- Follows project conventions (no `as any`, proper error handling) ✓

**Key Patterns Applied:**
1. Non-blocking UI: isLoading state doesn't block during background polling
2. Distance calculation: Haversine formula for accurate geodesic distance
3. Threshold-based updates: Only pushes to server if >500m movement
4. Graceful degradation: GPS → City fallback → Manual entry
5. Silent background updates: Polling doesn't show loading state to user

**Dependencies:**
- Convex mutation: `api.users.updateLocation`
- External API: Nominatim OpenStreetMap (no API key required)
- Browser API: navigator.geolocation


### Task 3: searchTaskers Query (TDD)
- Status: ✅ Complete
- Started: 2026-02-02 08:48
- Completed: 2026-02-02 08:51
- Commit: a3a01f2a

#### Implementation Summary
Created basic tasker search query with strict TDD approach:
- **RED Phase**: Wrote 6 tests first, confirmed failures
- **GREEN Phase**: Implemented query to pass all tests (6/6 passing)

#### Files Created
- `convex/search.ts` - Search query implementation (102 lines)
- `convex/__tests__/search.test.ts` - Test suite (289 lines)

#### Query Interface
```typescript
searchTaskers(categorySlug?, lat, lng, radiusKm)
```

**Parameters:**
- `categorySlug`: Optional category filter (e.g., "cleaning")
- `lat, lng, radiusKm`: Required but not used yet (placeholder for Task 4)

**Returns:**
```typescript
{
  id: Id<"taskerProfiles">,
  userId: Id<"users">,
  name: string,
  category: string,
  rating: number,
  reviews: number,
  price: string,
  distance: string,
  verified: boolean,
  bio: string | null,
  completedJobs: number
}[]
```

#### Tests (All Passing)
1. ✅ Returns taskers in category
2. ✅ Excludes ghostMode=true taskers
3. ✅ Excludes isOnboarded=false taskers
4. ✅ Returns empty array when no matches
5. ✅ Returns formatted data with expected fields
6. ✅ Formats fixed rate correctly ($150 flat)

#### Implementation Details

**Filtering Logic:**
- Uses `by_ghostMode` index to filter out ghost mode taskers
- Checks `isOnboarded=true` in handler
- Joins taskerProfiles → taskerCategories → categories
- Filters by category if categorySlug provided

**Price Formatting:**
```typescript
hourlyRate: 5000 (cents) → "$50/hr"
fixedRate: 15000 (cents) → "$150 flat"
```

**Distance Placeholder:**
- Returns hardcoded "0.0 km" (Task 4 will implement geospatial)

**TypeScript Patterns:**
- Explicit typing: `Doc<"categories"> | null`
- Null safety with `?? null` and optional chaining
- Avoided `as any` - used proper type annotations

#### Query Pattern
```typescript
1. Look up category by slug (if provided)
2. Query taskerProfiles with by_ghostMode index
3. Filter isOnboarded=true
4. For each profile:
   - Query taskerCategories by taskerProfile
   - Match categoryId if filtering
   - Fetch category details
   - Format price from rate data
   - Build result object
```

#### Test Patterns Learned

**Manual Database Insertion for Edge Cases:**
When API doesn't support creating certain states (e.g., isOnboarded=false), use `t.run()`:
```typescript
const taskerProfileId = await t.run(async (ctx) => {
  const profileId = await ctx.db.insert("taskerProfiles", {
    isOnboarded: false, // Can't do this via createTaskerProfile
    // ... other fields
  });
  return profileId;
});
```

**Patch for State Changes:**
```typescript
await t.run(async (ctx) => {
  await ctx.db.patch(taskerProfileId, { ghostMode: true });
});
```

#### Patterns Followed
- ✅ Query returns null/empty array (doesn't throw)
- ✅ Uses .withIndex() for filtering
- ✅ Proper TypeScript types (no any)
- ✅ convex-test module mapping
- ✅ Test isolation (unique identities)
- ✅ Comments follow existing test patterns

#### What This Task Does NOT Include
- ❌ Actual geospatial radius filtering (Task 4)
- ❌ Distance calculation (hardcoded placeholder)
- ❌ Pagination
- ❌ Sorting by distance/rating
- ❌ Return exact coordinates (returns distance string only)

#### Dependencies
- ✅ Schema: taskerProfiles, taskerCategories, categories tables
- ✅ Indexes: by_ghostMode, by_taskerProfile, by_category, by_slug
- ❌ @get-convex/geospatial (Task 4 will add this)

#### Blocks
- Task 4: Geospatial search (will enhance this query with real distance filtering)

#### Next Steps
- Task 4: Add geospatial filtering with @get-convex/geospatial
- Task 4: Calculate real distance from user location
- Task 4: Sort by distance
- Task 6: Add pagination

### Task 4: Geospatial Search + Overlap Logic
- Status: ✅ Complete
- Completed: 2026-02-02
- Files: `convex/geospatial.ts`, `convex/location.ts`, `convex/search.ts`, `convex/__tests__/search.test.ts`

#### Implementation Summary
- Added `taskerGeo` geospatial index and insert on tasker location updates (primary category filter key).
- Updated search to use `taskerGeo.nearest` with maxDistance (seeker radius + 250km) and service area overlap check.
- Distance strings now formatted from real geospatial distances.

#### Test Updates
- Added overlap tests (190km match, 210km no-match).
- Registered geospatial component in convex-test with manual component module mapping (Bun lacks `import.meta.glob`).
- Updated location/search tests to use dynamic module mapping for geospatial registration.

#### Verification
- `bun test convex/__tests__/search.test.ts` (8/8 passing)

## Task 6: Wire HomeSwipe to Real Data
- Integrated `useQuery(api.search.searchTaskers)` into HomeSwipe.tsx.
- Connected `useUserLocation` for geospatial search.
- Added explicit loading state (spinner) and empty state (message + filter controls).
- Used `useEffect` to reset card index when filters change.
- Verified build success.
