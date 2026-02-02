# Mock Payment Bypass Implementation

## TL;DR

> **Quick Summary**: Create a backend mutation to update subscription plans and wire it to the frontend, bypassing actual payment processing. All "purchases" immediately succeed.
> 
> **Deliverables**:
> - `updateSubscriptionPlan` mutation in convex/taskers.ts
> - `setGhostMode` mutation for toggling visibility
> - Frontend integration in Subscriptions.tsx and App.tsx
> - Test coverage for new mutations
> 
> **Estimated Effort**: Quick (2-3 hours)
> **Parallel Execution**: NO - sequential (mutations before frontend)
> **Critical Path**: Task 1 (mutation) -> Task 2 (ghost mode) -> Task 3 (frontend) -> Task 4 (tests)

---

## Context

### Original Request
Pause the Stripe payment integration from IMPLEMENTATION_PLAN.md Phase 7 since RevenueCat will be used for the production mobile app. Instead, wire the payment screens to assume success when the user clicks through.

### Interview Summary
**Key Discussions**:
- Real payments will use RevenueCat (not Stripe) once mobile app is in production
- Need subscription functionality working now for development/testing
- Ghost mode and premium features should work correctly based on subscription status

**Research Findings**:
- Schema already has `subscriptionPlan: "none" | "basic" | "premium"` field in taskerProfiles
- UI screens exist (Subscriptions.tsx, PremiumUpgrade.tsx) but only update local state
- No backend mutation exists to persist subscription changes
- Ghost mode field exists but no mutation to toggle it

---

## Work Objectives

### Core Objective
Enable subscriptions to persist across sessions by creating backend mutations that immediately "succeed" without payment processing, allowing full testing of subscription-gated features.

### Concrete Deliverables
- `convex/taskers.ts`: `updateSubscriptionPlan` mutation
- `convex/taskers.ts`: `setGhostMode` mutation  
- `src/screens/Subscriptions.tsx`: Call mutation on subscribe
- `src/App.tsx`: Sync local state with Convex
- `convex/__tests__/taskers.test.ts`: Test coverage

### Definition of Done
- [ ] User can select Basic or Premium plan and have it persist to database
- [ ] Refresh page and subscription status is retained
- [ ] Ghost mode toggle works and persists
- [ ] Premium gate (multiple categories) works based on persisted subscription

### Must Have
- Backend mutations with proper auth checks
- Ghost mode automatically disabled when subscription activated
- Timestamps updated on subscription change

### Must NOT Have (Guardrails)
- NO Stripe integration or payment SDK
- NO billing history or transaction records
- NO subscription expiration logic (treat as permanent for now)
- NO price validation or plan change restrictions

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (Vitest + convex-test)
- **User wants tests**: YES (Tests after implementation)
- **Framework**: Vitest with convex-test

### Automated Verification

Each TODO includes executable verification:

**For Backend mutations** (using convex-test):
```bash
cd Patchwork_MCP && npm run test:run
# Assert: All tests pass including new subscription tests
```

**For Frontend integration** (using Playwright or manual):
```bash
# Start dev server, navigate to tasker flow, subscribe
# Refresh page, verify subscription persists
```

---

## Execution Strategy

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 3 | None |
| 2 | 1 | 3 | None |
| 3 | 1, 2 | 4 | None |
| 4 | 1, 2, 3 | None | None |

### Sequential Execution
All tasks are sequential - backend first, frontend second, tests last.

---

## TODOs

- [ ] 1. Create updateSubscriptionPlan mutation

  **What to do**:
  - Add mutation to `convex/taskers.ts`
  - Accept `plan: "basic" | "premium"` argument
  - Update taskerProfile's `subscriptionPlan` field
  - Set `ghostMode: false` when subscription activated (user becomes visible)
  - If Premium, generate a unique `premiumPin` (6-digit number)
  - Update `updatedAt` timestamp

  **Must NOT do**:
  - No payment validation
  - No subscription history tracking
  - No plan downgrade restrictions

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file modification, straightforward mutation pattern
  - **Skills**: `[]`
    - No special skills needed - standard Convex mutation

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (first task)
  - **Blocks**: Tasks 2, 3
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `convex/taskers.ts:124-161` - `updateTaskerProfile` mutation shows the auth/lookup/patch pattern to follow
  - `convex/taskers.ts:47-48` - Shows where `subscriptionPlan` and `ghostMode` are initialized

  **API/Type References**:
  - `convex/schema.ts:65-69` - subscriptionPlan union type definition: `"none" | "basic" | "premium"`
  - `convex/schema.ts:95-97` - premiumPin field (optional string for Premium users)

  **Test References**:
  - `convex/__tests__/taskers.test.ts:72` - Existing test shows subscriptionPlan defaults to "none"

  **Acceptance Criteria**:

  **Automated Verification:**
  ```bash
  # After implementation, run tests:
  cd Patchwork_MCP && npm run test:run -- --grep "subscription"
  # Assert: All tests pass
  ```

  **Mutation contract (verify manually or with test):**
  ```typescript
  // Call: updateSubscriptionPlan({ plan: "premium" })
  // Result: 
  //   - taskerProfile.subscriptionPlan === "premium"
  //   - taskerProfile.ghostMode === false
  //   - taskerProfile.premiumPin is 6-digit string (Premium only)
  //   - taskerProfile.updatedAt is recent timestamp
  ```

  **Commit**: YES
  - Message: `feat(subscriptions): add updateSubscriptionPlan mutation for mock payments`
  - Files: `convex/taskers.ts`
  - Pre-commit: `npm run test:run`

---

- [ ] 2. Create setGhostMode mutation

  **What to do**:
  - Add mutation to `convex/taskers.ts`
  - Accept `ghostMode: boolean` argument
  - Only allow setting ghostMode if user has active subscription ("basic" or "premium")
  - Return error if trying to enable ghostMode without subscription (shouldn't be possible from UI, but enforce on backend)
  - Update `updatedAt` timestamp

  **Must NOT do**:
  - No subscription tier logic (both Basic and Premium can toggle)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file, mirrors existing pattern
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (after Task 1)
  - **Blocks**: Task 3
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `convex/taskers.ts:124-161` - Same auth/lookup/patch pattern

  **API/Type References**:
  - `convex/schema.ts:71` - ghostMode boolean field

  **Acceptance Criteria**:

  **Automated Verification:**
  ```typescript
  // Test case:
  // 1. Create tasker with subscription: "none"
  // 2. Call setGhostMode({ ghostMode: true }) -> expect error
  // 3. Call updateSubscriptionPlan({ plan: "basic" })
  // 4. Call setGhostMode({ ghostMode: true }) -> expect success
  // 5. Query profile -> ghostMode === true
  ```

  **Commit**: YES (group with Task 1)
  - Message: `feat(subscriptions): add setGhostMode mutation with subscription validation`
  - Files: `convex/taskers.ts`
  - Pre-commit: `npm run test:run`

---

- [ ] 3. Wire frontend to use mutations

  **What to do**:
  - In `Subscriptions.tsx`:
    - Import `useMutation` and `api.taskers.updateSubscriptionPlan`
    - Add loading state while mutation executes
    - Call mutation in `onSubscribe` handler before calling parent callback
    - Handle mutation error with toast/alert
  
  - In `App.tsx`:
    - Import tasker profile query
    - Sync `subscriptionPlan` state from Convex data
    - Remove local-only state updates where Convex is source of truth
  
  - In `Profile.tsx` (if needed):
    - Wire "Activate Subscription" button to navigate to subscriptions
    - Wire ghost mode toggle to call `setGhostMode` mutation

  **Must NOT do**:
  - Don't remove the local state entirely yet (keep as fallback during loading)
  - Don't add payment forms or Stripe components

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward wiring, well-defined patterns
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (after Tasks 1, 2)
  - **Blocks**: Task 4
  - **Blocked By**: Tasks 1, 2

  **References**:

  **Pattern References**:
  - `src/screens/CreateProfile.tsx` - Example of using `useMutation` for backend calls
  - `src/screens/Chat.tsx:469-476` - Example of mutation with loading state

  **API/Type References**:
  - `src/screens/Subscriptions.tsx:8` - Current `onSubscribe` callback signature

  **Test References**:
  - `src/App.tsx:101-103` - Current local subscription state management

  **Documentation References**:
  - `Patchwork_MCP/src/screens/AGENTS.md` - Screen navigation patterns
  - `Patchwork_MCP/AGENTS.md:1.5` - Auth readiness pattern for gating queries

  **Acceptance Criteria**:

  **Automated Verification (Playwright or manual):**
  ```
  1. Start app: npm run dev
  2. Sign in as existing tasker user
  3. Navigate to Profile -> "Activate Subscription"
  4. Select Premium plan -> Click Subscribe
  5. Verify: Loading state shows during mutation
  6. Verify: Navigate to profile after success
  7. Refresh page (Cmd+R)
  8. Verify: Profile still shows Premium subscription (persisted!)
  9. Toggle Ghost Mode off
  10. Refresh page
  11. Verify: Ghost Mode still off (persisted!)
  ```

  **Evidence to Capture:**
  - Console should show no errors
  - Network tab should show Convex mutation calls

  **Commit**: YES
  - Message: `feat(subscriptions): wire frontend to use backend mutations`
  - Files: `src/screens/Subscriptions.tsx`, `src/App.tsx`, `src/screens/Profile.tsx`
  - Pre-commit: `npm run build`

---

- [ ] 4. Add test coverage for subscription mutations

  **What to do**:
  - Add tests to `convex/__tests__/taskers.test.ts`:
    - Test `updateSubscriptionPlan` sets plan correctly
    - Test `updateSubscriptionPlan` clears ghostMode on activation
    - Test `updateSubscriptionPlan` generates premiumPin for Premium only
    - Test `setGhostMode` fails without subscription
    - Test `setGhostMode` succeeds with subscription
  - Follow existing test patterns with `convex-test`

  **Must NOT do**:
  - Don't test payment flow (doesn't exist)
  - Don't test subscription expiration (not implemented)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Established testing patterns, clear assertions
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (final task)
  - **Blocks**: None
  - **Blocked By**: Tasks 1, 2, 3

  **References**:

  **Pattern References**:
  - `convex/__tests__/taskers.test.ts` - Existing tasker tests to follow
  - `convex/__tests__/users.test.ts` - Auth pattern with `t.withIdentity()`

  **Acceptance Criteria**:

  **Automated Verification:**
  ```bash
  cd Patchwork_MCP && npm run test:run
  # Assert: All tests pass
  # Assert: Coverage includes new mutations
  ```

  **Commit**: YES
  - Message: `test(subscriptions): add coverage for subscription and ghost mode mutations`
  - Files: `convex/__tests__/taskers.test.ts`
  - Pre-commit: `npm run test:run`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1, 2 | `feat(subscriptions): add subscription and ghost mode mutations` | convex/taskers.ts | npm run test:run |
| 3 | `feat(subscriptions): wire frontend to backend mutations` | src/screens/*.tsx, src/App.tsx | npm run build |
| 4 | `test(subscriptions): add coverage for subscription mutations` | convex/__tests__/taskers.test.ts | npm run test:run |

---

## Success Criteria

### Verification Commands
```bash
# Backend tests pass
cd Patchwork_MCP && npm run test:run

# Build succeeds  
cd Patchwork_MCP && npm run build

# Manual: Subscription persists across page refresh
```

### Final Checklist
- [ ] User can subscribe to Basic or Premium
- [ ] Subscription persists across sessions (stored in Convex)
- [ ] Ghost mode toggle works and persists
- [ ] Premium gate (multiple categories) works with persisted subscription
- [ ] No Stripe or payment SDK code added
- [ ] All tests pass

---

## Future: RevenueCat Integration

When ready for production mobile app:

1. **Add RevenueCat SDK** to React Native project
2. **Create verification mutation**:
   ```typescript
   export const verifySubscription = mutation({
     args: { revenueCatUserId: v.string(), entitlements: v.array(v.string()) },
     handler: async (ctx, args) => {
       // Verify entitlements from RevenueCat
       // Map to "basic" | "premium" based on product IDs
       // Call existing updateSubscriptionPlan logic
     }
   });
   ```
3. **Replace frontend flow**: Instead of calling `updateSubscriptionPlan` directly, show RevenueCat paywall and call `verifySubscription` after purchase.

The mock bypass created by this plan will serve as the foundation - same schema, same mutations, just different trigger (RevenueCat webhook vs direct call).
