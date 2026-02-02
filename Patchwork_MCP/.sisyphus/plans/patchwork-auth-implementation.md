# Patchwork Auth Implementation (Phases 1-2)

## TL;DR

> **Quick Summary**: Initialize Convex backend with better-auth authentication (Google OAuth + Email OTP), implement user profile management with TDD, and integrate auth into existing frontend screens.
> 
> **Deliverables**:
> - Convex backend initialized with schema
> - better-auth configured (Google OAuth + Email OTP)
> - User profile mutations/queries with tests
> - Profile photo upload via Convex file storage
> - Frontend auth screens integrated with real auth
> 
> **Estimated Effort**: Medium (2-3 days)
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Manual Setup → Convex Init → Schema → Auth Config → Frontend Integration

---

## Context

### Original Request
Implement Phases 1-2 from IMPLEMENTATION_PLAN.md: Convex project setup and better-auth authentication with TDD approach and frontend integration.

### Interview Summary
**Key Decisions**:
- Auth methods: Google OAuth + Email OTP (6-digit code)
- Skip: Apple Sign In (too complex), Stripe (production uses RevenueCat)
- Email delivery: Console log only (internal testing)
- Return user flow: Home if profile exists, CreateProfile if new
- Profile photos: Include Convex file storage setup
- Web UI is internal testing tool only

**Research Findings**:
- Pin `@convex-dev/better-auth@0.9.7` and `better-auth@1.4.9` for compatibility
- Use `npx convex env set` for auth secrets (NOT .env.local)
- OAuth callback URL: `https://<deployment>.convex.site/api/auth/callback/google`
- Use `emailOTP` plugin (matches existing 6-digit input UI)
- Test with `convex-test` + `t.withIdentity()` for auth mocking

### Metis Review
**Identified Gaps** (addressed):
- Magic Link vs OTP confusion → Confirmed Email OTP
- Email service requirement → Console log for dev
- Return user redirect logic → Smart redirect based on profile existence
- Profile photo scope → Include with Convex file storage

---

## Work Objectives

### Core Objective
Set up Convex backend with better-auth authentication so users can sign in via Google or Email OTP and create/view their profile.

### Concrete Deliverables
- `convex/` folder with schema, auth config, user functions
- `src/lib/auth.ts` - better-auth client setup
- `src/lib/convex.ts` - Convex React client setup
- Updated `src/main.tsx` with ConvexProvider
- Updated auth screens: SignIn, CreateAccount, EmailEntry, EmailVerify, CreateProfile
- Test files: `convex/__tests__/users.test.ts`

### Definition of Done
- [ ] `npx convex dev --once` exits with code 0 (no schema errors)
- [ ] `npm test -- --run` passes all auth tests
- [ ] Google OAuth redirects to accounts.google.com (not 404)
- [ ] Email OTP code appears in Convex dev console
- [ ] New user can create profile with photo
- [ ] Returning user redirected to Home

### Must Have
- Google OAuth sign-in flow
- Email OTP sign-in flow
- createProfile mutation with photo upload
- getCurrentUser query
- TDD tests for user functions
- Smart redirect (new → CreateProfile, returning → Home)

### Must NOT Have (Guardrails)
- ❌ Apple Sign In (explicitly deferred)
- ❌ Stripe/payment integration (production uses RevenueCat)
- ❌ Messaging, Jobs, Proposals (Phases 4-5)
- ❌ Search/Geospatial (Phase 6)
- ❌ React Router migration (keep current useState navigation)
- ❌ Email service integration (console log only)
- ❌ Tasker profiles (Phase 3)

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: NO (setting up)
- **User wants tests**: YES (TDD)
- **Framework**: Vitest + convex-test
- **QA approach**: TDD for Convex functions, manual browser testing for OAuth flow

### TDD Structure
Each Convex function task follows RED-GREEN-REFACTOR:
1. **RED**: Write failing test first
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Clean up while keeping tests green

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 0 (Manual - User Action Required):
└── Task 0: Verify manual setup (Google OAuth credentials, Convex account)

Wave 1 (Start After Wave 0):
├── Task 1: Initialize Convex project
├── Task 2: Install dependencies (better-auth, convex-test, vitest)
└── Task 3: Create schema (users, seekerProfiles tables only)

Wave 2 (After Wave 1):
├── Task 4: Write tests for user functions (TDD - RED phase)
├── Task 5: Configure better-auth (Google OAuth + Email OTP)
└── Task 6: Set up Convex file storage for photos

Wave 3 (After Wave 2):
├── Task 7: Implement user mutations/queries (TDD - GREEN phase)
├── Task 8: Create auth client (src/lib/auth.ts)
└── Task 9: Create Convex client (src/lib/convex.ts)

Wave 4 (After Wave 3):
├── Task 10: Update main.tsx with providers
├── Task 11: Update SignIn + CreateAccount screens
├── Task 12: Update EmailEntry + EmailVerify screens
├── Task 13: Update CreateProfile screen with photo upload
└── Task 14: Update App.tsx with auth state + smart redirect

Wave 5 (Final):
└── Task 15: End-to-end verification
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 0 | None | 1, 2, 3 | None (manual step) |
| 1 | 0 | 3, 5 | 2 |
| 2 | 0 | 4, 5, 6 | 1 |
| 3 | 1 | 4, 7 | 2 |
| 4 | 2, 3 | 7 | 5, 6 |
| 5 | 1, 2 | 8, 11, 12 | 4, 6 |
| 6 | 2 | 13 | 4, 5 |
| 7 | 4 | 10, 14 | 8, 9 |
| 8 | 5 | 11, 12 | 7, 9 |
| 9 | 1 | 10 | 7, 8 |
| 10 | 7, 9 | 11-14 | None |
| 11 | 8, 10 | 15 | 12, 13, 14 |
| 12 | 8, 10 | 15 | 11, 13, 14 |
| 13 | 6, 10 | 15 | 11, 12, 14 |
| 14 | 7, 10 | 15 | 11, 12, 13 |
| 15 | 11, 12, 13, 14 | None | None (final) |

---

## TODOs

- [ ] 0. **MANUAL CHECKPOINT: Verify Prerequisites**

  **What to do**:
  - This is a USER ACTION task - the agent should verify and report status
  - Check if Google OAuth credentials exist in Google Cloud Console
  - Verify Convex account is created (https://convex.dev)
  - Generate BETTER_AUTH_SECRET (32+ random characters)
  
  **Verification checklist**:
  - [ ] Google Cloud Console project exists
  - [ ] OAuth 2.0 Client ID created (Web application type)
  - [ ] Authorized redirect URI includes: `http://localhost:3000/api/auth/callback/google`
  - [ ] Client ID and Client Secret noted
  - [ ] Convex account created at convex.dev
  - [ ] BETTER_AUTH_SECRET generated (use `openssl rand -base64 32`)

  **Must NOT do**:
  - Do NOT proceed if credentials are missing - report blockers

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 0 (blocking)
  - **Blocks**: Tasks 1, 2, 3
  - **Blocked By**: None

  **References**:
  - `Patchwork_MCP/MANUAL_STEPS.md:16-27` - Google OAuth setup instructions
  - `Patchwork_MCP/MANUAL_STEPS.md:82-93` - Convex setup instructions

  **Acceptance Criteria**:
  - [ ] Agent reports: "Google OAuth credentials verified" or "BLOCKER: Missing Google OAuth credentials"
  - [ ] Agent reports: "Convex account ready" or "BLOCKER: Convex account not set up"
  - [ ] If blockers exist, agent provides specific instructions from MANUAL_STEPS.md

  **Commit**: NO (verification only)

---

- [ ] 1. **Initialize Convex Project**

  **What to do**:
  - Run `npx convex dev` to initialize Convex in the project
  - This creates `convex/` folder and `convex/_generated/` types
  - Accept project creation prompts
  - Note the deployment URL for OAuth callback configuration

  **Must NOT do**:
  - Do NOT create schema yet (separate task)
  - Do NOT set environment variables yet

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2)
  - **Blocks**: Tasks 3, 5, 9
  - **Blocked By**: Task 0

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:89-100` - Convex init instructions

  **Acceptance Criteria**:
  ```bash
  # Verify convex folder created
  ls -la Patchwork_MCP/convex/
  # Assert: _generated/ folder exists
  
  # Verify convex starts without errors
  cd Patchwork_MCP && npx convex dev --once
  # Assert: Exit code 0
  ```

  **Commit**: YES
  - Message: `feat(backend): initialize Convex project`
  - Files: `convex/`, `convex.json`

---

- [ ] 2. **Install Dependencies**

  **What to do**:
  - Install better-auth with pinned versions:
    ```bash
    npm install convex@latest
    npm install @convex-dev/better-auth@0.9.7 better-auth@1.4.9 --save-exact
    ```
  - Install test dependencies:
    ```bash
    npm install -D convex-test vitest @vitest/coverage-v8 @edge-runtime/vm
    ```
  - Add test scripts to package.json:
    ```json
    {
      "scripts": {
        "test": "vitest",
        "test:run": "vitest run",
        "test:coverage": "vitest run --coverage"
      }
    }
    ```
  - Create `vitest.config.ts` for edge runtime

  **Must NOT do**:
  - Do NOT install @testing-library/react yet (not needed for Convex tests)
  - Do NOT install Stripe

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Task 1)
  - **Blocks**: Tasks 4, 5, 6
  - **Blocked By**: Task 0

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:104-108` - better-auth install
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:696-734` - Vitest setup

  **Acceptance Criteria**:
  ```bash
  # Verify packages installed
  cd Patchwork_MCP && npm ls better-auth @convex-dev/better-auth convex-test vitest
  # Assert: Shows better-auth@1.4.9, @convex-dev/better-auth@0.9.7
  
  # Verify test command exists
  npm run test -- --help
  # Assert: Shows vitest help
  ```

  **Commit**: YES
  - Message: `chore(deps): add better-auth, convex-test, and vitest`
  - Files: `package.json`, `package-lock.json`, `vitest.config.ts`

---

- [ ] 3. **Create Database Schema (Users + SeekerProfiles Only)**

  **What to do**:
  - Create `convex/schema.ts` with ONLY users and seekerProfiles tables
  - Copy from CONVEX_SCHEMA.md but include ONLY these two tables
  - Add proper indexes for auth lookups

  **Schema content**:
  ```typescript
  // convex/schema.ts
  import { defineSchema, defineTable } from "convex/server";
  import { v } from "convex/values";

  export default defineSchema({
    users: defineTable({
      authId: v.string(),
      email: v.string(),
      emailVerified: v.boolean(),
      name: v.string(),
      photo: v.optional(v.id("_storage")),
      location: v.object({
        city: v.string(),
        province: v.string(),
        coordinates: v.optional(v.object({
          lat: v.number(),
          lng: v.number(),
        })),
      }),
      roles: v.object({
        isSeeker: v.boolean(),
        isTasker: v.boolean(),
      }),
      settings: v.object({
        notificationsEnabled: v.boolean(),
        locationEnabled: v.boolean(),
      }),
      createdAt: v.number(),
      updatedAt: v.number(),
    })
      .index("by_authId", ["authId"])
      .index("by_email", ["email"]),

    seekerProfiles: defineTable({
      userId: v.id("users"),
      jobsPosted: v.number(),
      completedJobs: v.number(),
      rating: v.number(),
      ratingCount: v.number(),
      favouriteTaskers: v.array(v.id("users")),
      updatedAt: v.number(),
    }).index("by_userId", ["userId"]),
  });
  ```

  **Must NOT do**:
  - Do NOT add taskerProfiles, categories, jobs, messages, etc.
  - Do NOT copy the full CONVEX_SCHEMA.md (only users + seekerProfiles)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Task 1)
  - **Parallel Group**: Wave 1 (after Task 1 completes)
  - **Blocks**: Tasks 4, 7
  - **Blocked By**: Task 1

  **References**:
  - `Patchwork_MCP/CONVEX_SCHEMA.md:17-82` - users and seekerProfiles definitions

  **Acceptance Criteria**:
  ```bash
  # Verify schema pushes without errors
  cd Patchwork_MCP && npx convex dev --once
  # Assert: Exit code 0, "Schema synced" or similar message
  
  # Verify schema file exists
  cat Patchwork_MCP/convex/schema.ts | grep "defineSchema"
  # Assert: Contains defineSchema
  ```

  **Commit**: YES
  - Message: `feat(schema): add users and seekerProfiles tables`
  - Files: `convex/schema.ts`

---

- [ ] 4. **Write Tests for User Functions (TDD - RED Phase)**

  **What to do**:
  - Create `convex/__tests__/users.test.ts`
  - Write failing tests for:
    1. `createProfile` - creates user and seekerProfile
    2. `getCurrentUser` - returns null when unauthenticated
    3. `getCurrentUser` - returns user when authenticated
  - Tests should FAIL at this point (functions don't exist yet)

  **Test file structure**:
  ```typescript
  // convex/__tests__/users.test.ts
  import { convexTest } from "convex-test";
  import { expect, test, describe } from "vitest";
  import { api } from "../_generated/api";
  import schema from "../schema";

  describe("users", () => {
    test("createProfile creates user and seekerProfile", async () => {
      const t = convexTest(schema);
      
      const asUser = t.withIdentity({
        tokenIdentifier: "google|123",
        email: "test@example.com",
      });

      const userId = await asUser.mutation(api.users.createProfile, {
        name: "Test User",
        city: "Toronto",
        province: "ON",
      });

      expect(userId).toBeDefined();

      const user = await asUser.query(api.users.getCurrentUser);
      expect(user?.name).toBe("Test User");
      expect(user?.email).toBe("test@example.com");
    });

    test("getCurrentUser returns null when unauthenticated", async () => {
      const t = convexTest(schema);
      const user = await t.query(api.users.getCurrentUser);
      expect(user).toBeNull();
    });

    test("getCurrentUser returns user when authenticated", async () => {
      const t = convexTest(schema);
      
      const asUser = t.withIdentity({
        tokenIdentifier: "google|456",
        email: "existing@example.com",
      });

      // First create a profile
      await asUser.mutation(api.users.createProfile, {
        name: "Existing User",
        city: "Vancouver",
        province: "BC",
      });

      // Then verify getCurrentUser returns it
      const user = await asUser.query(api.users.getCurrentUser);
      expect(user).not.toBeNull();
      expect(user?.name).toBe("Existing User");
    });

    test("createProfile throws when unauthenticated", async () => {
      const t = convexTest(schema);
      
      await expect(
        t.mutation(api.users.createProfile, {
          name: "Should Fail",
          city: "Montreal",
          province: "QC",
        })
      ).rejects.toThrow();
    });
  });
  ```

  **Must NOT do**:
  - Do NOT implement the functions yet (this is RED phase)
  - Do NOT write tests for tasker functions

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 6)
  - **Blocks**: Task 7
  - **Blocked By**: Tasks 2, 3

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:756-791` - convex-test examples
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:322-377` - createProfile, getCurrentUser logic

  **Acceptance Criteria**:
  ```bash
  # Tests should FAIL (RED phase)
  cd Patchwork_MCP && npm run test:run -- convex/__tests__/users.test.ts
  # Assert: Tests fail with "api.users.createProfile is not defined" or similar
  # This is expected! RED phase = tests exist but code doesn't
  ```

  **Commit**: YES
  - Message: `test(users): add TDD tests for createProfile and getCurrentUser`
  - Files: `convex/__tests__/users.test.ts`

---

- [ ] 5. **Configure Better Auth (Google OAuth + Email OTP)**

  **What to do**:
  - Create `convex/auth.ts` with better-auth configuration
  - Set up Google OAuth provider
  - Set up Email OTP provider (console.log delivery for dev)
  - Create `convex/auth.config.ts` for Convex component registration
  - Set environment variables using `npx convex env set`

  **Files to create**:

  ```typescript
  // convex/auth.config.ts
  import { convexAuth } from "@convex-dev/better-auth";
  import { defineApp } from "convex/server";

  const app = defineApp();
  app.use(convexAuth);
  export default app;
  ```

  ```typescript
  // convex/auth.ts
  import Google from "@auth/core/providers/google";
  import { getAuthConfigProvider } from "@convex-dev/better-auth";

  export default getAuthConfigProvider({
    providers: [
      Google({
        clientId: process.env.GOOGLE_CLIENT_ID!,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
      }),
    ],
    emailOTP: {
      async sendOTP({ email, otp }) {
        // For development: log to console
        console.log(`📧 OTP for ${email}: ${otp}`);
      },
    },
  });
  ```

  **Environment variables** (set via Convex CLI):
  ```bash
  npx convex env set BETTER_AUTH_SECRET "your-32-char-secret"
  npx convex env set GOOGLE_CLIENT_ID "your-google-client-id"
  npx convex env set GOOGLE_CLIENT_SECRET "your-google-client-secret"
  ```

  **Must NOT do**:
  - Do NOT add Apple provider
  - Do NOT use .env.local for auth secrets (must use `npx convex env set`)
  - Do NOT set up actual email service (console.log only)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 6)
  - **Blocks**: Tasks 8, 11, 12
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:183-206` - Better Auth config
  - Metis findings on @convex-dev/better-auth@0.9.7 patterns

  **Acceptance Criteria**:
  ```bash
  # Verify auth config compiles
  cd Patchwork_MCP && npx convex dev --once
  # Assert: No TypeScript errors in auth.ts or auth.config.ts
  
  # Verify env vars are set (check Convex dashboard or CLI)
  npx convex env list
  # Assert: Shows BETTER_AUTH_SECRET, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
  ```

  **Commit**: YES
  - Message: `feat(auth): configure better-auth with Google OAuth and Email OTP`
  - Files: `convex/auth.ts`, `convex/auth.config.ts`

---

- [ ] 6. **Set Up Convex File Storage for Profile Photos**

  **What to do**:
  - Create `convex/files.ts` with upload URL generator and URL getter
  - File upload flow: client gets upload URL → uploads to Convex storage → saves storage ID to user profile

  **Files to create**:
  ```typescript
  // convex/files.ts
  import { mutation, query } from "./_generated/server";
  import { v } from "convex/values";

  export const generateUploadUrl = mutation({
    handler: async (ctx) => {
      const identity = await ctx.auth.getUserIdentity();
      if (!identity) throw new Error("Not authenticated");
      
      return await ctx.storage.generateUploadUrl();
    },
  });

  export const getUrl = query({
    args: { storageId: v.id("_storage") },
    handler: async (ctx, { storageId }) => {
      return await ctx.storage.getUrl(storageId);
    },
  });
  ```

  **Must NOT do**:
  - Do NOT implement complex file validation (keep simple for Phase 1-2)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5)
  - **Blocks**: Task 13
  - **Blocked By**: Task 2

  **References**:
  - Convex file storage docs: https://docs.convex.dev/file-storage

  **Acceptance Criteria**:
  ```bash
  # Verify file functions compile
  cd Patchwork_MCP && npx convex dev --once
  # Assert: No errors, files.ts functions registered
  ```

  **Commit**: YES
  - Message: `feat(files): add Convex file storage for profile photos`
  - Files: `convex/files.ts`

---

- [ ] 7. **Implement User Mutations/Queries (TDD - GREEN Phase)**

  **What to do**:
  - Create `convex/users.ts` with createProfile and getCurrentUser
  - Implement until all tests from Task 4 pass
  - Include photo storage ID in createProfile

  **Implementation**:
  ```typescript
  // convex/users.ts
  import { mutation, query } from "./_generated/server";
  import { v } from "convex/values";

  export const createProfile = mutation({
    args: {
      name: v.string(),
      city: v.string(),
      province: v.string(),
      photo: v.optional(v.id("_storage")),
    },
    handler: async (ctx, args) => {
      const identity = await ctx.auth.getUserIdentity();
      if (!identity) throw new Error("Not authenticated");

      // Check if user already exists
      const existing = await ctx.db
        .query("users")
        .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
        .first();

      if (existing) {
        throw new Error("User already exists");
      }

      const now = Date.now();

      const userId = await ctx.db.insert("users", {
        authId: identity.tokenIdentifier,
        email: identity.email!,
        emailVerified: identity.emailVerified ?? false,
        name: args.name,
        photo: args.photo,
        location: {
          city: args.city,
          province: args.province,
        },
        roles: {
          isSeeker: true,
          isTasker: false,
        },
        settings: {
          notificationsEnabled: true,
          locationEnabled: false,
        },
        createdAt: now,
        updatedAt: now,
      });

      // Create seeker profile
      await ctx.db.insert("seekerProfiles", {
        userId,
        jobsPosted: 0,
        completedJobs: 0,
        rating: 0,
        ratingCount: 0,
        favouriteTaskers: [],
        updatedAt: now,
      });

      return userId;
    },
  });

  export const getCurrentUser = query({
    handler: async (ctx) => {
      const identity = await ctx.auth.getUserIdentity();
      if (!identity) return null;

      const user = await ctx.db
        .query("users")
        .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
        .first();

      return user;
    },
  });
  ```

  **Must NOT do**:
  - Do NOT add tasker-related functions
  - Do NOT over-engineer (keep minimal to pass tests)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 8, 9)
  - **Blocks**: Tasks 10, 14
  - **Blocked By**: Task 4

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:322-377` - User management example
  - Test file: `convex/__tests__/users.test.ts`

  **Acceptance Criteria**:
  ```bash
  # All tests should PASS (GREEN phase)
  cd Patchwork_MCP && npm run test:run -- convex/__tests__/users.test.ts
  # Assert: All 4 tests pass
  ```

  **Commit**: YES
  - Message: `feat(users): implement createProfile and getCurrentUser mutations`
  - Files: `convex/users.ts`

---

- [ ] 8. **Create Auth Client (src/lib/auth.ts)**

  **What to do**:
  - Create `src/lib/auth.ts` with better-auth React client
  - Export auth hooks for use in components

  **Implementation**:
  ```typescript
  // src/lib/auth.ts
  import { createAuthClient } from "better-auth/react";

  export const authClient = createAuthClient({
    baseURL: import.meta.env.VITE_BETTER_AUTH_URL || "http://localhost:3000",
  });

  // Convenience hooks
  export const useAuth = () => authClient.useSession();
  export const signInWithGoogle = () => authClient.signIn.social({ provider: "google", callbackURL: "/" });
  export const signInWithEmailOtp = (email: string) => authClient.signIn.emailOtp({ email });
  export const verifyEmailOtp = (email: string, otp: string) => authClient.signIn.emailOtp({ email, otp });
  export const signOut = () => authClient.signOut();
  ```

  **Must NOT do**:
  - Do NOT add Apple sign in method

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 7, 9)
  - **Blocks**: Tasks 11, 12
  - **Blocked By**: Task 5

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:192-206` - Auth client setup

  **Acceptance Criteria**:
  ```bash
  # Verify file compiles (TypeScript check)
  cd Patchwork_MCP && npx tsc --noEmit src/lib/auth.ts
  # Assert: No TypeScript errors
  ```

  **Commit**: YES
  - Message: `feat(auth): create better-auth React client`
  - Files: `src/lib/auth.ts`

---

- [ ] 9. **Create Convex Client (src/lib/convex.ts)**

  **What to do**:
  - Create `src/lib/convex.ts` with Convex React client setup

  **Implementation**:
  ```typescript
  // src/lib/convex.ts
  import { ConvexReactClient } from "convex/react";

  export const convex = new ConvexReactClient(
    import.meta.env.VITE_CONVEX_URL as string
  );
  ```

  **Must NOT do**:
  - Do NOT add authentication provider wrapping here (done in main.tsx)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 7, 8)
  - **Blocks**: Task 10
  - **Blocked By**: Task 1

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:213-221` - Convex provider setup

  **Acceptance Criteria**:
  ```bash
  # Verify file exists and has correct export
  grep -q "ConvexReactClient" Patchwork_MCP/src/lib/convex.ts
  # Assert: Exit code 0
  ```

  **Commit**: YES (can combine with Task 8)
  - Message: `feat(convex): create Convex React client`
  - Files: `src/lib/convex.ts`

---

- [ ] 10. **Update main.tsx with Providers**

  **What to do**:
  - Wrap App with ConvexProvider
  - Add VITE_CONVEX_URL to .env.local

  **Implementation**:
  ```typescript
  // src/main.tsx
  import React from "react";
  import ReactDOM from "react-dom/client";
  import { ConvexProvider } from "convex/react";
  import { convex } from "./lib/convex";
  import App from "./App";
  import "./index.css";

  ReactDOM.createRoot(document.getElementById("root")!).render(
    <React.StrictMode>
      <ConvexProvider client={convex}>
        <App />
      </ConvexProvider>
    </React.StrictMode>
  );
  ```

  **Also update .env.local**:
  ```bash
  VITE_CONVEX_URL=https://your-deployment.convex.cloud
  VITE_BETTER_AUTH_URL=http://localhost:3000
  ```

  **Must NOT do**:
  - Do NOT change routing system
  - Do NOT add other providers yet

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (start)
  - **Blocks**: Tasks 11, 12, 13, 14
  - **Blocked By**: Tasks 7, 9

  **References**:
  - `Patchwork_MCP/IMPLEMENTATION_PLAN.md:208-221` - Provider setup
  - `Patchwork_MCP/src/main.tsx` - Current main.tsx to update

  **Acceptance Criteria**:
  ```bash
  # Verify app starts without errors
  cd Patchwork_MCP && npm run dev &
  sleep 5
  curl -s http://localhost:5173 | grep -q "root"
  # Assert: Page loads (contains root div)
  ```

  **Commit**: YES
  - Message: `feat(app): wrap with ConvexProvider`
  - Files: `src/main.tsx`, `.env.local`

---

- [ ] 11. **Update SignIn + CreateAccount Screens**

  **What to do**:
  - Remove Apple Sign In button
  - Wire up Google button to `signInWithGoogle()`
  - Wire up Email button to navigate to EmailEntry
  - Keep existing UI/styling

  **Key changes**:
  ```typescript
  // In SignIn.tsx
  import { signInWithGoogle } from "../lib/auth";

  // Replace mock handler
  const handleGoogleSignIn = async () => {
    await signInWithGoogle();
  };

  // Remove Apple button or hide it
  ```

  **Must NOT do**:
  - Do NOT change UI design/styling
  - Do NOT add Apple functionality
  - Do NOT change navigation pattern (keep useState-based)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: `["frontend-ui-ux"]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 12, 13, 14)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 8, 10

  **References**:
  - `Patchwork_MCP/src/screens/SignIn.tsx` - Current implementation
  - `Patchwork_MCP/src/screens/CreateAccount.tsx` - Current implementation

  **Acceptance Criteria**:
  ```bash
  # Verify screens compile
  cd Patchwork_MCP && npx tsc --noEmit src/screens/SignIn.tsx src/screens/CreateAccount.tsx
  # Assert: No TypeScript errors
  
  # Manual browser test (agent should document steps):
  # 1. Open http://localhost:5173
  # 2. Navigate to SignIn screen
  # 3. Click "Continue with Google"
  # 4. Assert: Redirects to accounts.google.com (not 404)
  ```

  **Commit**: YES
  - Message: `feat(auth): integrate Google OAuth in SignIn and CreateAccount`
  - Files: `src/screens/SignIn.tsx`, `src/screens/CreateAccount.tsx`

---

- [ ] 12. **Update EmailEntry + EmailVerify Screens**

  **What to do**:
  - Wire up EmailEntry to call `signInWithEmailOtp(email)`
  - Wire up EmailVerify to call `verifyEmailOtp(email, otp)`
  - Store email in state to pass between screens
  - On successful verification, navigate based on user profile existence

  **Key changes**:
  ```typescript
  // In EmailEntry.tsx
  import { signInWithEmailOtp } from "../lib/auth";

  const handleContinue = async () => {
    await signInWithEmailOtp(email);
    navigate("email-verify", { email }); // Pass email to verify screen
  };

  // In EmailVerify.tsx
  import { verifyEmailOtp } from "../lib/auth";

  const handleVerify = async () => {
    await verifyEmailOtp(email, otp);
    // Navigation handled by App.tsx auth state
  };
  ```

  **Must NOT do**:
  - Do NOT set up actual email sending (console.log is fine)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: `["frontend-ui-ux"]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 11, 13, 14)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 8, 10

  **References**:
  - `Patchwork_MCP/src/screens/EmailEntry.tsx` - Current implementation
  - `Patchwork_MCP/src/screens/EmailVerify.tsx` - Current implementation

  **Acceptance Criteria**:
  ```bash
  # Verify screens compile
  cd Patchwork_MCP && npx tsc --noEmit src/screens/EmailEntry.tsx src/screens/EmailVerify.tsx
  # Assert: No TypeScript errors
  
  # Manual test (document in verification):
  # 1. Enter email, click Continue
  # 2. Check Convex dev console for OTP log
  # 3. Enter OTP in verify screen
  # 4. Assert: Navigates to CreateProfile (new user)
  ```

  **Commit**: YES
  - Message: `feat(auth): integrate Email OTP in EmailEntry and EmailVerify`
  - Files: `src/screens/EmailEntry.tsx`, `src/screens/EmailVerify.tsx`

---

- [ ] 13. **Update CreateProfile Screen with Photo Upload**

  **What to do**:
  - Add photo upload using Convex file storage
  - Call `createProfile` mutation with photo storage ID
  - Handle upload progress/errors

  **Key changes**:
  ```typescript
  // In CreateProfile.tsx
  import { useMutation } from "convex/react";
  import { api } from "../../convex/_generated/api";

  const createProfile = useMutation(api.users.createProfile);
  const generateUploadUrl = useMutation(api.files.generateUploadUrl);

  const handlePhotoUpload = async (file: File) => {
    const uploadUrl = await generateUploadUrl();
    const result = await fetch(uploadUrl, {
      method: "POST",
      headers: { "Content-Type": file.type },
      body: file,
    });
    const { storageId } = await result.json();
    setPhotoStorageId(storageId);
  };

  const handleSubmit = async () => {
    await createProfile({
      name,
      city,
      province,
      photo: photoStorageId,
    });
    navigate("home");
  };
  ```

  **Must NOT do**:
  - Do NOT add complex image cropping/editing
  - Do NOT change UI layout significantly

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: `["frontend-ui-ux"]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 11, 12, 14)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 6, 10

  **References**:
  - `Patchwork_MCP/src/screens/CreateProfile.tsx` - Current implementation
  - Convex file upload docs

  **Acceptance Criteria**:
  ```bash
  # Verify screen compiles
  cd Patchwork_MCP && npx tsc --noEmit src/screens/CreateProfile.tsx
  # Assert: No TypeScript errors
  ```

  **Commit**: YES
  - Message: `feat(profile): add photo upload and createProfile integration`
  - Files: `src/screens/CreateProfile.tsx`

---

- [ ] 14. **Update App.tsx with Auth State + Smart Redirect**

  **What to do**:
  - Add `useAuth()` hook for session state
  - Add `useQuery(api.users.getCurrentUser)` for profile state
  - Implement smart redirect:
    - If authenticated + no profile → CreateProfile
    - If authenticated + has profile → Home
    - If unauthenticated → SignIn/Onboarding

  **Key changes**:
  ```typescript
  // In App.tsx
  import { useQuery } from "convex/react";
  import { api } from "../convex/_generated/api";
  import { useAuth } from "./lib/auth";

  function App() {
    const { data: session, isPending: authLoading } = useAuth();
    const user = useQuery(api.users.getCurrentUser);

    // Smart redirect logic
    useEffect(() => {
      if (authLoading) return; // Wait for auth to load
      
      if (session && !user) {
        // Authenticated but no profile
        navigate("create-profile");
      } else if (session && user) {
        // Authenticated with profile - go to home if on auth screen
        if (["sign-in", "create-account", "email-entry", "email-verify", "create-profile"].includes(currentScreen)) {
          navigate("home");
        }
      }
    }, [session, user, authLoading]);

    // ... rest of component
  }
  ```

  **Must NOT do**:
  - Do NOT change the navigation system to React Router
  - Do NOT remove existing mock data patterns (just add auth layer on top)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 11, 12, 13)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 7, 10

  **References**:
  - `Patchwork_MCP/src/App.tsx` - Current implementation
  - Metis analysis on navigation patterns

  **Acceptance Criteria**:
  ```bash
  # Verify App.tsx compiles
  cd Patchwork_MCP && npx tsc --noEmit src/App.tsx
  # Assert: No TypeScript errors
  ```

  **Commit**: YES
  - Message: `feat(app): add auth state and smart redirect logic`
  - Files: `src/App.tsx`

---

- [ ] 15. **End-to-End Verification**

  **What to do**:
  - Run full test suite
  - Manually test complete auth flows:
    1. Google OAuth: Sign in → Create profile → Home
    2. Email OTP: Enter email → Get OTP (console) → Verify → Create profile → Home
    3. Return user: Sign in → Home (skip create profile)
  - Document any issues found

  **Must NOT do**:
  - Do NOT fix issues here (create follow-up tasks if needed)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `["playwright"]` (for browser automation if available)

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5 (final)
  - **Blocks**: None
  - **Blocked By**: Tasks 11, 12, 13, 14

  **References**:
  - All previous task outputs

  **Acceptance Criteria**:
  ```bash
  # 1. All tests pass
  cd Patchwork_MCP && npm run test:run
  # Assert: All tests pass

  # 2. Convex dev server runs without errors
  npx convex dev --once
  # Assert: Exit code 0

  # 3. App starts and loads
  npm run dev &
  sleep 5
  curl -s http://localhost:5173 | grep -q "root"
  # Assert: Page loads

  # 4. Manual verification checklist:
  # - [ ] Google Sign In redirects to Google
  # - [ ] Email OTP appears in Convex console
  # - [ ] Profile creation works with photo
  # - [ ] Return user goes to Home
  ```

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files |
|------------|---------|-------|
| 1 | `feat(backend): initialize Convex project` | convex/, convex.json |
| 2 | `chore(deps): add better-auth, convex-test, and vitest` | package.json, vitest.config.ts |
| 3 | `feat(schema): add users and seekerProfiles tables` | convex/schema.ts |
| 4 | `test(users): add TDD tests for createProfile and getCurrentUser` | convex/__tests__/users.test.ts |
| 5 | `feat(auth): configure better-auth with Google OAuth and Email OTP` | convex/auth.ts, convex/auth.config.ts |
| 6 | `feat(files): add Convex file storage for profile photos` | convex/files.ts |
| 7 | `feat(users): implement createProfile and getCurrentUser mutations` | convex/users.ts |
| 8+9 | `feat(lib): create auth and Convex React clients` | src/lib/auth.ts, src/lib/convex.ts |
| 10 | `feat(app): wrap with ConvexProvider` | src/main.tsx, .env.local |
| 11 | `feat(auth): integrate Google OAuth in SignIn and CreateAccount` | src/screens/SignIn.tsx, CreateAccount.tsx |
| 12 | `feat(auth): integrate Email OTP in EmailEntry and EmailVerify` | src/screens/EmailEntry.tsx, EmailVerify.tsx |
| 13 | `feat(profile): add photo upload and createProfile integration` | src/screens/CreateProfile.tsx |
| 14 | `feat(app): add auth state and smart redirect logic` | src/App.tsx |

---

## Success Criteria

### Verification Commands
```bash
# All tests pass
npm run test:run

# Convex dev server starts
npx convex dev --once

# App builds without errors
npm run build
```

### Final Checklist
- [ ] Convex backend initialized and running
- [ ] better-auth configured with Google OAuth + Email OTP
- [ ] User tests pass (createProfile, getCurrentUser)
- [ ] Profile photo upload works
- [ ] Auth screens integrated (SignIn, CreateAccount, EmailEntry, EmailVerify, CreateProfile)
- [ ] Smart redirect working (new user → CreateProfile, returning → Home)
- [ ] No Apple Sign In (explicitly excluded)
- [ ] No Stripe integration (explicitly excluded)
