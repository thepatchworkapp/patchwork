# Patchwork Admin Dashboard

## TL;DR

> **Quick Summary**: Create a standalone admin dashboard outside Patchwork_MCP/ to view and manage users, their profiles, jobs, and reviews. Uses Vite + Effect TS with email OTP auth hardcoded to daveald@gmail.com.
> 
> **Deliverables**:
> - New `patchwork-admin/` project at repo root
> - Email OTP auth (hardcoded admin email, console OTP)
> - User list with expandable detail rows
> - Read-only admin queries in Convex (separate from user UI)
> - Vitest test coverage
> 
> **Estimated Effort**: Medium (6-8 hours)
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Task 1 (project setup) → Task 2 (auth) → Task 4 (user list) → Task 6 (tests)

---

## Context

### Original Request
Create an admin dashboard outside of Patchwork_MCP/ structure. Standalone project, separate deployment URL. Features:
- User list view
- Expandable user rows showing: account types, profile info, images, categories, job history, ratings
- Email OTP auth hardcoded to daveald@gmail.com (OTP in console)
- Don't modify existing Convex functions
- Write tests

### Interview Summary
**Key Decisions**:
- Tech stack: Vite + Effect TS (functional patterns for data transformation)
- Location: `/patchwork-admin/` at repo root (sibling to Patchwork_MCP/)
- Auth: Simple email OTP, hardcoded admin email for now
- Data: Read-only admin queries in new `convex/admin.ts` file
- UI: Consult frontend designer for layout (master-detail pattern likely)

**Constraints**:
- MUST NOT modify any existing Convex functions used by user UI
- MUST create new admin-specific queries
- MUST use same Convex deployment (reads same database)

---

## Work Objectives

### Core Objective
Build a read-only admin dashboard that provides visibility into all users, their profiles, activity, and system state.

### Concrete Deliverables
- `patchwork-admin/` - Vite + Effect TS project
- `Patchwork_MCP/convex/admin.ts` - Admin-only queries (read-only)
- User list page with search/filter
- User detail view (expandable or drill-down)
- Email OTP authentication
- Vitest tests

### Definition of Done
- [x] Admin can log in with daveald@gmail.com + console OTP
- [x] Admin can see list of all users
- [x] Admin can expand/click user to see full details
- [x] User details show: roles, seeker profile, tasker profile, categories, jobs, reviews
- [x] No existing Convex functions modified
- [x] Tests pass
- [x] Build succeeds

### Must Have
- Authentication gate (only daveald@gmail.com can access)
- User list with pagination or virtual scroll
- User detail expansion showing all related data
- Loading and error states
- Responsive layout (desktop-first, but usable on tablet)

### Must NOT Have (Guardrails)
- NO modifications to existing Convex mutations/queries
- NO write operations (read-only dashboard for now)
- NO user impersonation
- NO production deployment in this phase

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (new project)
- **User wants tests**: YES
- **Framework**: Vitest (same as Patchwork_MCP for consistency)

### Test Coverage Plan
1. Admin queries (convex-test)
2. Auth flow (unit tests)
3. Component rendering (React Testing Library)

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Project setup (Vite + Effect TS + Convex)
└── Task 3: Admin queries in Convex

Wave 2 (After Wave 1):
├── Task 2: Email OTP auth
├── Task 4: User list page (depends on Task 3)
└── Task 5: User detail view (depends on Task 3)

Wave 3 (After Wave 2):
└── Task 6: Tests
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 4, 5 | 3 |
| 2 | 1 | 4, 5 | - |
| 3 | None | 4, 5, 6 | 1 |
| 4 | 1, 2, 3 | 6 | 5 |
| 5 | 1, 2, 3 | 6 | 4 |
| 6 | 4, 5 | None | None |

---

## TODOs

- [x] 1. Project Setup: Create patchwork-admin with Vite + Effect TS

  **What to do**:
  - Create `patchwork-admin/` directory at repo root
  - Initialize Vite project with React + TypeScript template
  - Install dependencies: effect, @effect/schema, convex, tailwindcss
  - Configure Convex client to connect to same deployment
  - Set up Tailwind CSS
  - Create basic App.tsx with routing placeholder

  **Must NOT do**:
  - Do NOT install React Router (use simple state-based navigation like main app)
  - Do NOT create complex folder structure yet

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward project scaffolding
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 3)
  - **Blocks**: Tasks 2, 4, 5
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `Patchwork_MCP/package.json` - Reference for Convex version and setup
  - `Patchwork_MCP/vite.config.ts` - Vite configuration pattern
  - `Patchwork_MCP/tailwind.config.ts` - Tailwind setup

  **Acceptance Criteria**:
  ```bash
  cd patchwork-admin && npm run dev
  # Should start Vite dev server
  # Should show basic React app
  ```

  **Commit**: YES
  - Message: `feat(admin): scaffold patchwork-admin project with Vite + Effect TS`
  - Files: `patchwork-admin/*`

---

- [x] 2. Implement Email OTP Authentication

  **What to do**:
  - Create `patchwork-admin/src/lib/auth.ts` with simple OTP logic
  - Hardcode admin email: `daveald@gmail.com`
  - Generate 6-digit OTP and log to console (no email sending)
  - Store OTP in Convex `otps` table (reuse existing table)
  - Create login page component
  - Add auth context/provider to gate access
  - Redirect unauthenticated users to login

  **Must NOT do**:
  - Do NOT use Better Auth (too complex for admin)
  - Do NOT send real emails
  - Do NOT allow any email other than hardcoded admin

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple auth flow, minimal complexity
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (after Task 1)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `Patchwork_MCP/convex/schema.ts:388-392` - Existing `otps` table schema
  - `Patchwork_MCP/src/screens/EmailVerify.tsx` - OTP verification UI pattern

  **API/Type References**:
  - `Patchwork_MCP/convex/schema.ts` - otps table: `{ email, otp, createdAt }`

  **Acceptance Criteria**:
  ```
  1. Navigate to http://localhost:5174 (admin port)
  2. See login page
  3. Enter daveald@gmail.com -> Click "Send OTP"
  4. Check console for OTP
  5. Enter OTP -> Click "Verify"
  6. Redirected to dashboard
  7. Refresh page -> Still authenticated
  8. Enter wrong email -> Error message
  ```

  **Commit**: YES
  - Message: `feat(admin): add email OTP authentication`
  - Files: `patchwork-admin/src/lib/auth.ts`, `patchwork-admin/src/pages/Login.tsx`

---

- [x] 3. Create Admin-Only Convex Queries

  **What to do**:
  - Create `Patchwork_MCP/convex/admin.ts` with read-only queries
  - `listAllUsers` - Paginated list of all users with basic info
  - `getUserDetail` - Full user detail with all related data
  - Include: user, seekerProfile, taskerProfile, taskerCategories, jobs, reviews
  - Add proper indexes if needed for pagination
  - Do NOT add auth checks (admin auth is handled at app level)

  **Must NOT do**:
  - Do NOT modify any existing queries/mutations
  - Do NOT add write operations
  - Do NOT expose sensitive data (no passwords, auth tokens)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward query composition
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Tasks 4, 5, 6
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `Patchwork_MCP/convex/users.ts` - Query patterns
  - `Patchwork_MCP/convex/taskers.ts:82-121` - `getTaskerProfile` pattern for joining data

  **API/Type References**:
  - `Patchwork_MCP/convex/schema.ts` - All table schemas

  **Acceptance Criteria**:
  ```typescript
  // listAllUsers returns:
  {
    users: [{
      _id, email, name, photo, location, roles,
      createdAt, updatedAt
    }],
    cursor: string | null
  }

  // getUserDetail returns:
  {
    user: { ...fullUser },
    seekerProfile: { ...profile } | null,
    taskerProfile: { ...profile, categories: [...] } | null,
    jobsAsSeeker: [...],
    jobsAsTasker: [...],
    reviewsGiven: [...],
    reviewsReceived: [...]
  }
  ```

  **Commit**: YES
  - Message: `feat(admin): add admin-only read queries`
  - Files: `Patchwork_MCP/convex/admin.ts`

---

- [x] 4. Build User List Page

  **What to do**:
  - Create `patchwork-admin/src/pages/UserList.tsx`
  - Display all users in a table/list format
  - Show: email, name, roles (seeker/tasker badges), created date
  - Add search/filter by email or name
  - Implement pagination or infinite scroll
  - Make rows clickable/expandable
  - Use Effect TS for data transformation if beneficial
  - **CONSULT FRONTEND DESIGNER** for optimal layout

  **Must NOT do**:
  - Do NOT implement complex filtering (keep simple for MVP)
  - Do NOT add bulk actions yet

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI-heavy task, needs designer input
  - **Skills**: `["frontend-ui-ux"]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 5)
  - **Blocks**: Task 6
  - **Blocked By**: Tasks 1, 2, 3

  **References**:

  **Pattern References**:
  - `Patchwork_MCP/src/screens/Jobs.tsx` - List rendering pattern
  - `Patchwork_MCP/src/components/ui/table.tsx` - If exists, shadcn table component

  **Acceptance Criteria**:
  ```
  1. See list of all users
  2. Each row shows: avatar/initials, name, email, role badges
  3. Can search by name or email
  4. Can click row to expand/navigate to detail
  5. Handles loading state
  6. Handles empty state
  ```

  **Commit**: YES
  - Message: `feat(admin): build user list page with search`
  - Files: `patchwork-admin/src/pages/UserList.tsx`

---

- [x] 5. Build User Detail View

  **What to do**:
  - Create `patchwork-admin/src/pages/UserDetail.tsx` OR expandable row component
  - Display comprehensive user information:
    - Basic info: name, email, photo, location, created date
    - Roles: seeker/tasker badges
    - Seeker profile: jobs posted, completed, rating
    - Tasker profile: display name, bio, subscription, ghost mode, categories
    - Categories: list with rates, service radius, stats
    - Job history: recent jobs as seeker and tasker
    - Reviews: given and received
  - Show images from Convex storage (use `ctx.storage.getUrl`)
  - Use collapsible sections for organization
  - **CONSULT FRONTEND DESIGNER** for layout

  **Must NOT do**:
  - Do NOT add edit functionality
  - Do NOT show raw IDs (resolve to names)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Complex UI layout, needs designer input
  - **Skills**: `["frontend-ui-ux"]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Task 6
  - **Blocked By**: Tasks 1, 2, 3

  **References**:

  **Pattern References**:
  - `Patchwork_MCP/src/screens/Profile.tsx` - Profile display patterns
  - `Patchwork_MCP/src/screens/ProviderDetail.tsx` - Tasker detail display

  **API/Type References**:
  - `Patchwork_MCP/convex/files.ts` - `getUrl` for storage URLs

  **Acceptance Criteria**:
  ```
  1. Click user in list -> See full details
  2. See profile photo (if exists)
  3. See seeker stats (if seeker)
  4. See tasker profile with categories (if tasker)
  5. See job history with status
  6. See reviews given and received
  7. Can collapse/expand sections
  8. Back button returns to list
  ```

  **Commit**: YES
  - Message: `feat(admin): build user detail view`
  - Files: `patchwork-admin/src/pages/UserDetail.tsx`

---

- [x] 6. Add Test Coverage

  **What to do**:
  - Set up Vitest in patchwork-admin
  - Create `patchwork-admin/vitest.config.ts`
  - Test admin queries with convex-test:
    - `listAllUsers` returns paginated results
    - `getUserDetail` returns complete data structure
  - Test auth flow:
    - Login with correct email succeeds
    - Login with wrong email fails
    - OTP verification works
  - Test components with React Testing Library:
    - UserList renders users
    - UserDetail renders all sections
    - Loading states appear

  **Must NOT do**:
  - Do NOT test existing Patchwork_MCP functions
  - Do NOT aim for 100% coverage (focus on critical paths)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Follow established test patterns
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (final)
  - **Blocks**: None
  - **Blocked By**: Tasks 4, 5

  **References**:

  **Pattern References**:
  - `Patchwork_MCP/convex/__tests__/*.test.ts` - convex-test patterns
  - `Patchwork_MCP/vitest.config.ts` - Vitest configuration

  **Acceptance Criteria**:
  ```bash
  cd patchwork-admin && npm run test:run
  # All tests pass
  # Coverage includes: admin queries, auth, components
  ```

  **Commit**: YES
  - Message: `test(admin): add comprehensive test coverage`
  - Files: `patchwork-admin/**/*.test.ts`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(admin): scaffold project` | patchwork-admin/* | npm run dev |
| 2 | `feat(admin): add email OTP auth` | patchwork-admin/src/* | manual login test |
| 3 | `feat(admin): add admin queries` | Patchwork_MCP/convex/admin.ts | npm run test:run |
| 4, 5 | `feat(admin): build user views` | patchwork-admin/src/pages/* | npm run build |
| 6 | `test(admin): add coverage` | patchwork-admin/**/*.test.ts | npm run test:run |

---

## Success Criteria

### Verification Commands
```bash
# Admin dashboard builds
cd patchwork-admin && npm run build

# Admin tests pass
cd patchwork-admin && npm run test:run

# Main app tests still pass (no regressions)
cd Patchwork_MCP && npm run test:run
```

### Final Checklist
- [x] Admin can log in with hardcoded email
- [x] User list displays all users
- [x] User detail shows complete information
- [x] Images load from Convex storage
- [x] No existing Convex functions modified
- [x] All tests pass
- [x] Both projects build successfully

---

## Technical Notes

### Effect TS Usage
Consider using Effect for:
- Data transformation pipelines (joining user data)
- Error handling with typed errors
- Schema validation for API responses

Example:
```typescript
import { Effect, pipe } from "effect";
import * as S from "@effect/schema/Schema";

const UserSchema = S.Struct({
  _id: S.String,
  email: S.String,
  name: S.String,
  roles: S.Struct({
    isSeeker: S.Boolean,
    isTasker: S.Boolean,
  }),
});

const transformUsers = (rawData: unknown) =>
  pipe(
    S.decodeUnknown(S.Array(UserSchema))(rawData),
    Effect.map((users) => users.filter((u) => u.roles.isTasker)),
  );
```

### Convex Connection
Both apps share the same Convex deployment:
```typescript
// patchwork-admin/src/lib/convex.ts
import { ConvexReactClient } from "convex/react";

export const convex = new ConvexReactClient(
  import.meta.env.VITE_CONVEX_URL // Same as Patchwork_MCP
);
```

### Port Configuration
- Patchwork_MCP: http://localhost:5173
- patchwork-admin: http://localhost:5174 (use `--port 5174`)

---

## Future Enhancements (Not in this plan)
- Admin write operations (suspend user, modify subscription)
- Analytics dashboard (user growth, job metrics)
- System health monitoring
- Audit logging
- Multi-admin support with proper auth
