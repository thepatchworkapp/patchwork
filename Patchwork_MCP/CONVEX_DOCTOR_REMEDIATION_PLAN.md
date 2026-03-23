# Convex Doctor Remediation Plan

Date: March 9, 2026
Command: `npx convex-doctor --verbose`
Workspace: `/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_MCP`

## Snapshot

- Score: `49/100` (`Critical`)
- Findings: `17 errors`, `294 warnings`, `175 infos`
- Primary risk buckets:
  - Security and correctness issues that can change runtime behavior or expose endpoints incorrectly.
  - Query determinism and performance issues that can break caching or hide data-integrity problems.
  - Schema/index drift that creates avoidable scans and makes future maintenance harder.
  - Architectural cleanup warnings that should be handled after behavioral risk is reduced.

## Progress Log

- March 9, 2026: Slice 1 completed.
- March 9, 2026: `convex-doctor` improved from `49/100` with `17` errors to `66/100` with `9` errors after the first remediation pass.
- March 9, 2026: Verified with `npx convex codegen`, focused Vitest coverage for `messages` and `reviews`, and an iOS simulator build via `xcodebuild`.
- March 9, 2026: Bounded the remaining unbounded test-helper reads in `convex/testing.ts`.
- March 9, 2026: `convex-doctor` improved again to `72/100` with `1` remaining error, now limited to the `_generated` working-tree warning.
- March 9, 2026: Slice 2 completed. Added shared return validators, normalized several public response payloads, and replaced the remaining `taskerCategories` filter scans with compound-index lookups.
- March 9, 2026: Slice 3 completed. Added low-risk return validators to touched public mutations and removed the last flagged `cleanupConversations` table-scan filter.
- March 9, 2026: Verified Slice 2 and Slice 3 with `npx convex codegen` plus focused Vitest coverage for `users`, `categories`, `taskers`, `search`, and `messages`.
- March 9, 2026: `convex-doctor` improved to `74/100` with `1` error, `265` warnings, and `168` infos. The only remaining error is still the generated-files working-tree warning.
- March 9, 2026: Slice 4 completed. Replaced generic `Error` throws with `ConvexError` across the remaining production messaging, location, review, proposal, conversation, job, and job-request flows.
- March 9, 2026: Added return validators for conversations, proposals, reviews, location, jobs, and job requests; updated the corresponding tests where the stricter contracts required explicit pagination payloads.
- March 9, 2026: Moved helper-only validator/subscription modules from `convex/` to `lib/convex/` so Convex codegen no longer treats them as API modules. This cleared the `_generated/api.d.ts` diff without hand-editing generated code.
- March 9, 2026: Slice 5 completed. Converted the remaining testing-helper `throw new Error(...)` sites to `ConvexError`.
- March 9, 2026: Verified the current remediation state with `npx convex codegen` and focused Vitest coverage for `users`, `categories`, `taskers`, `search`, `messages`, `conversations`, `proposals`, `reviews`, `jobs`, `location`, and `security`.
- March 9, 2026: `convex-doctor` improved to `79/100` with `0` errors, `236` warnings, and `8` infos.
- March 9, 2026: Production deploy completed successfully to `https://vibrant-caribou-150.convex.cloud`.
- March 9, 2026: Verified live production reads with `npx convex run --prod categories:listCategories '{}'` and `npx convex run --prod search:searchTaskers '{"lat":43.6532,"lng":-79.3832,"radiusKm":25,"limit":5}'`.
- March 9, 2026: Verified the web client against production configuration with `npm run build` and `npm run test:run` using `VITE_CONVEX_URL=https://vibrant-caribou-150.convex.cloud` and `VITE_CONVEX_SITE_URL=https://vibrant-caribou-150.convex.site`.
- March 9, 2026: Updated iOS production endpoints in `Patchwork/Core/AppConfig.swift`, `Patchwork/Core/ConvexHTTPClient.swift`, and `PatchworkUITests/PatchworkUITests.swift` from `aware-meerkat-572` to `vibrant-caribou-150`.
- March 9, 2026: Verified iOS production configuration with `xcodebuild ... build` and `xcodebuild ... test` for the main scheme. App/unit-test coverage passed; UI-test coverage is only partially production-safe.
- March 9, 2026: Confirmed `https://vibrant-caribou-150.convex.site/test-proxy` returns `403 {"error":"Testing helpers are disabled"}` in production, which is the expected behavior because `ENABLE_TESTING_HELPERS=false` on prod.
- March 9, 2026: Targeted production-safe UI smoke tests remain unstable in the simulator. `testAuthFlowEntry()` passed, while `testAccessibilitySelectorsPresent()` and `testCreateAccountEntryRoutesToEmailFlow()` crashed with signal `kill` in `Test-Patchwork-2026.03.09_06-44-45--0400.xcresult`.
- March 9, 2026: Follow-up diagnosis showed the earlier iOS UI-test instability was not a production app regression. `testCreateAccountEntryRoutesToEmailFlow()` passed in isolation, and the full prod-safe smoke subset (`testAuthFlowEntry`, `testCreateAccountEntryRoutesToEmailFlow`, `testAccessibilitySelectorsPresent`) passed when rerun serially with a dedicated result bundle at `/tmp/patchwork-ui-smoke-1773053763.xcresult`.
- March 9, 2026: One earlier isolated failure was infrastructure-related: overlapping `xcodebuild` sessions produced result-bundle/runner errors (`Diagnostics couldn’t be removed`, early unexpected exit before establishing connection). Treat the iOS UI harness as serial-only for reliable results.

## Guiding Rules

- Do not try to clear all 294 warnings in one pass.
- Fix behavior-changing issues first, then performance/schema issues, then architectural cleanup.
- Preserve wire contracts for the iOS app unless there is a strong reason to change them.
- If a backend contract must change, update iOS in the same PR and verify both clients together.
- Treat `convex/_generated/*` as generated output only. Never hand-edit generated files as part of remediation.

## Phase 0: Baseline And Safety

- [x] Save the raw `convex-doctor` output in the PR description or an issue comment for before/after comparison.
- [x] Inspect the diff for `convex/_generated/api.d.ts` and confirm whether it was manually edited or drifted due to helper-only modules living under `convex/`.
- [x] Regenerate Convex types with the normal repo workflow and verify `_generated` changes disappear or become fully machine-generated.
- [x] Run `git diff -- convex/_generated` after regeneration and confirm no hand-authored edits remain.
- [ ] Record the current public backend contracts used by iOS before modifying validators or return shapes:
  - `users:getCurrentUser`
  - `users:createProfile`
  - `users:updateLocation`
  - `taskers:getTaskerProfile`
  - `taskers:getTaskerById`
  - `taskers:createTaskerProfile`
  - `taskers:updateSubscriptionPlan`
  - `taskers:cancelSubscription`
  - `taskers:setGhostMode`
  - `messages:listMessages`
  - `reviews:canReview`
  - `reviews:createReview`
- [ ] Decide whether to split the remediation into multiple PRs. Recommended split:
  - PR 1: security and correctness
  - PR 2: schema/index and performance
  - PR 3: architectural cleanup and false-positive cleanup

## Phase 1: Security And Correctness Blockers

### 1. Admin OTP route hardening

Files:
- `convex/http.ts`
- `convex/adminOtp.ts`

Tasks:
- [x] Convert the server-to-server OTP path to internal-only Convex functions.
- [x] Replace `ctx.runMutation(api.adminOtp.sendOTP, ...)` with `ctx.runMutation(internal.adminOtp.sendOTP, ...)`.
- [x] Replace `ctx.runMutation(api.adminOtp.verifyOTP, ...)` with `ctx.runMutation(internal.adminOtp.verifyOTP, ...)`.
- [x] Change `adminOtp.ts` exports to `internalMutation` if there are no direct public callers.
- [x] Add dedicated `OPTIONS` handlers for `/admin/send-otp` and `/admin/verify-otp`.
- [x] Centralize admin CORS headers so POST and OPTIONS stay aligned.
- [x] Preserve response payloads and HTTP status codes expected by the admin frontend.
- [x] Replace generic `Error` throws in `adminOtp.ts` with `ConvexError` codes/messages that the HTTP layer can safely surface.
- [ ] Re-run admin login flow after the change.

Verification:
- [ ] POST `/admin/send-otp` from the allowed admin origin succeeds.
- [ ] POST `/admin/send-otp` from a different origin fails with `403`.
- [ ] Browser preflight to both admin OTP endpoints succeeds.
- [ ] OTP verify success and failure cases still return readable error messages.

### 2. Missing validators on public functions

Files:
- `convex/categories.ts`
- `convex/taskers.ts`
- `convex/testingTasker.ts`
- `convex/users.ts`

Tasks:
- [x] Add explicit `args: {}` to zero-argument query/mutation handlers currently missing validators.
- [ ] Add `returns:` validators to public query/mutation handlers that currently return unvalidated data.
- [x] Add shared helper validators for repeated response shapes so return schemas do not get copy-pasted incorrectly.
- [ ] Start with endpoints consumed by production clients before test helpers and admin-only paths.
- [ ] Preserve payload field names and nullability when adding return validators.

Priority order:
- [x] `users:getCurrentUser`
- [x] `taskers:getTaskerProfile`
- [x] `taskers:getTaskerById`
- [x] `messages:listMessages`
- [ ] `reviews:canReview`
- [x] `categories:listCategories`
- [ ] Remaining admin and testing endpoints

Verification:
- [x] Convex deploy/codegen passes.
- [ ] iOS bootstrap still decodes `CurrentUser`, `TaskerProfileSelf`, `TaskerProfilePublic`, `MessagesPage`, and review eligibility.
- [x] Web and test consumers still accept the normalized payloads for `CurrentUser`, `TaskerProfileSelf`, `TaskerProfilePublic`, search results, and `MessagesPage`.
- [x] Conversations, proposals, reviews, jobs, and job requests still pass backend contract tests after validator tightening.

### 3. Deterministic queries

Files:
- `convex/reviews.ts`
- iOS touchpoints:
  - `Patchwork_iOS/Patchwork/Features/Jobs/JobDetailView.swift`
  - `Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift`

Problem:
- `reviews:canReview` uses `Date.now()` and `new Date()` inside a query, which breaks determinism and query caching.

Preferred fix:
- [x] Change `reviews:canReview` to accept a client-provided timestamp argument such as `currentTimeMs`.
- [x] Keep the result semantics identical.
- [x] Reuse the same timestamp for all eligibility checks inside the handler.
- [x] Add a return validator of `v.boolean()`.

iOS updates required if this contract changes:
- [x] Update both Swift call sites to pass `currentTimeMs`.
- [x] Use a single `Date().timeIntervalSince1970 * 1000` conversion path to avoid inconsistent units.
- [x] Keep the UI behavior unchanged for completed jobs and review CTA visibility.

Alternative:
- [ ] If preserving the existing API name is too risky, add a new deterministic query and migrate iOS to it before removing the old one.

Verification:
- [ ] `JobDetailView` still shows the review CTA only when appropriate.
- [ ] `MessagesView` still shows the review CTA for completed jobs.
- [ ] Review window edge cases around 30 days are covered with tests.

### 4. Unique lookup correctness

Files:
- `convex/admin.ts`
- `convex/adminOtp.ts`
- `convex/categories.ts`
- `convex/conversations.ts`
- `convex/jobRequests.ts`
- `convex/jobs.ts`
- `convex/location.ts`
- `convex/messages.ts`
- `convex/proposals.ts`
- `convex/reviews.ts`
- `convex/search.ts`
- `convex/taskers.ts`
- `convex/testing.ts`
- `convex/testingPhotos.ts`
- `convex/testingTasker.ts`
- `convex/users.ts`
- `convex/__tests__/reviews.test.ts`

Tasks:
- [ ] Replace `.first()` with `.unique()` only where the code assumes exactly one row.
- [ ] Do not blindly replace all `.first()` calls. Some are legitimate “take any one” lookups.
- [ ] Audit each lookup against schema/index semantics first.
- [ ] Where uniqueness is assumed but not enforced by schema, either:
  - add the appropriate uniqueness guarantee in business logic/tests, or
  - keep `.first()` and document why uniqueness is not guaranteed.
- [ ] Add regression tests for identity-based lookups such as `users.by_authId`, `taskerProfiles.by_userId`, and OTP-by-email lookups.

## Phase 2: Performance And Schema Safety

### 5. Pagination contract cleanup

Files:
- `convex/messages.ts`
- `Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift`

Tasks:
- [x] Confirm why doctor still flags `messages:listMessages` despite `paginationOpts` being present.
- [x] If the issue is optionality, make the validator shape match Convex’s expected paginated-query pattern.
- [x] If the server becomes strict about `paginationOpts`, remove the extra random `id` field from the iOS payload.
- [x] Keep `continueCursor` and `isDone` response fields stable for the Swift decoder.
- [ ] Add a test that a valid paginated call succeeds and an invalid pagination payload is rejected.

Likely iOS change:
- [x] Replace the current `optionsObject` with only supported keys:
  - `cursor`
  - `numItems`

### 6. Filter/index mismatches

Files:
- `convex/search.ts`
- `convex/taskers.ts`
- `convex/testing.ts`
- `convex/schema.ts`

Tasks:
- [x] Add or adjust indexes to cover `taskerCategories` lookups by both `taskerProfileId` and `categoryId`.
- [x] Replace `.withIndex(...).filter(...).first()` patterns with a direct compound-index lookup where possible.
- [x] Add an index on `categories.name` for the remaining exact-match helper lookup.
- [ ] Verify any new index name follows Convex naming convention.
- [ ] Re-run search and tasker profile flows to ensure the new indexes do not alter result ordering unexpectedly.

Recommended schema additions to evaluate:
- [ ] `taskerCategories.by_taskerProfile_and_category`
- [ ] Any exact-match index needed for category name lookups if that query is real and not dead/test code

### 7. Missing indexes on foreign keys and redundant indexes

Files:
- `convex/schema.ts`

Tasks:
- [ ] Review every `_storage` reference and add indexes only where the code actually queries those fields.
- [ ] Do not add indexes purely to satisfy the linter if no query path uses them.
- [ ] Remove redundant prefix indexes only after confirming no code depends on their independent sort order.
- [ ] Rename indexes that violate Convex naming conventions.
- [ ] Treat index renames as a migration event and test every affected `.withIndex(...)` call afterward.

Execution order:
- [ ] Add new indexes first.
- [ ] Update all `.withIndex(...)` callers.
- [ ] Deploy/test.
- [ ] Remove old redundant indexes last.

### 8. Unbounded reads and helper-vs-run issues in test helpers

Files:
- `convex/testing.ts`
- `convex/testingPhotos.ts`
- `convex/testingTasker.ts`

Tasks:
- [x] Bound all `.collect()` calls with realistic limits or pagination.
- [x] Replace `collect().filter(...)` with indexed or server-side filtering where the current helper usage made that practical.
- [ ] Inline helper logic rather than using `ctx.runMutation`/`ctx.runQuery` inside other Convex handlers where transaction sharing is intended.
- [ ] Keep testing helper behavior stable for UI tests and test proxy actions.
- [ ] Treat these as lower priority than production API fixes, but complete them before calling the doctor work done.
- [x] Convert testing-helper generic errors to `ConvexError` so test-only modules do not keep inflating production-style warning buckets.

## Phase 3: Authorization And Data Exposure Hardening

### 9. Spoofable review access

Files:
- `convex/reviews.ts`

Problem:
- `getUserReviews` authorizes via client-supplied `userId`.

Tasks:
- [ ] Decide whether `getUserReviews` should remain public for arbitrary profile pages or become scoped.
- [ ] If public-by-design, remove the security smell by treating it as a public profile endpoint and document that it is not an access-controlled route.
- [ ] If scoped, derive the subject user on the server from auth and stop trusting client-provided `userId`.
- [ ] Add a return validator for the review list shape.
- [ ] Confirm whether the iOS app calls this endpoint directly. Current native code appears to rely on `taskers:getTaskerById` for visible reviews instead.

### 10. Public mutations without auth checks

Files:
- `convex/auth.ts`
- `convex/categories.ts`
- `convex/files.ts`
- `convex/reviews.ts`
- `convex/search.ts`
- `convex/taskers.ts`
- `convex/adminOtp.ts`

Tasks:
- [ ] Review each warning individually to distinguish true issues from intentionally public endpoints.
- [ ] Keep `search:searchTaskers` public if anonymous browsing is a product requirement, but add return validation and document the exposure.
- [ ] Keep admin OTP functions internal-only after Phase 1 so the auth warning disappears naturally.
- [ ] For category seeding and test setup paths, decide whether they should be internal/admin-only instead of public.
- [ ] Ensure file upload URL generation requires auth if it is used by authenticated app flows only.

## Phase 4: Architecture Cleanup

### 11. Shared auth helpers and structured errors

Files:
- `convex/admin.ts`
- `convex/conversations.ts`
- `convex/jobs.ts`
- `convex/proposals.ts`
- `convex/reviews.ts`
- `convex/taskers.ts`
- `convex/users.ts`
- likely a new helper module such as `convex/lib/auth.ts` and `convex/lib/errors.ts`

Tasks:
- [ ] Extract repeated identity lookup into helpers such as:
  - `requireAuthUser(ctx)`
  - `getOptionalAuthUser(ctx)`
  - `requireAdmin(ctx)`
- [ ] Standardize on `ConvexError` payloads/codes for expected user-facing failures.
- [ ] Keep user-facing message strings stable where the iOS app displays raw backend errors.
- [ ] Add helper tests or at minimum broad regression coverage around auth-required flows.

### 12. Large handler and monolithic file reduction

Files:
- `convex/admin.ts`
- `convex/conversations.ts`
- `convex/jobRequests.ts`
- `convex/jobs.ts`
- `convex/location.ts`
- `convex/messages.ts`
- `convex/proposals.ts`
- `convex/reviews.ts`
- `convex/search.ts`
- `convex/taskers.ts`
- `convex/testing.ts`
- `convex/users.ts`

Tasks:
- [ ] Split by feature behavior, not by arbitrary line count.
- [ ] Keep public function names stable to avoid breaking client paths.
- [ ] Move unexported business logic into helper functions first.
- [ ] Split `testing.ts` aggressively because it has the highest warning density and lowest production risk.
- [ ] Delay file moves until after the security/correctness work is merged, otherwise review becomes noisy.

## iOS Compatibility Checklist

Files likely affected:
- `/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Jobs/JobDetailView.swift`
- `/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift`
- `/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Core/ConvexHTTPClient.swift`
- `/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Core/Models.swift`

Backend changes that likely require native updates:
- [x] `reviews:canReview` adds `currentTimeMs`.
- [x] `messages:listMessages` rejects the current extra `id` field in `paginationOpts`.
- [ ] Any return validator work that narrows nullable fields or removes undocumented properties.

Production endpoint alignment:
- [x] iOS app Convex cloud/site URLs now point at `vibrant-caribou-150`.
- [x] iOS UI tests use the production Convex site URL.
- [ ] Move iOS endpoint selection off hardcoded constants if staging/prod switching becomes necessary.

Backend changes that should not require native updates if implemented carefully:
- [ ] Swapping public/internal server references in admin OTP flow.
- [ ] Adding `args: {}` to zero-arg handlers while preserving payloads.
- [ ] Adding `returns:` validators that match the current response shape exactly.
- [ ] Replacing `Error` with `ConvexError` while keeping user-facing messages stable.
- [ ] Adding indexes or helper extraction without changing response contracts.

## Suggested Execution Order

1. Regenerate `_generated` output and isolate generated drift.
2. Fix admin OTP internal API misuse and missing CORS handling.
3. Add missing arg validators and return validators for production endpoints.
4. Make `reviews:canReview` deterministic and update iOS call sites in the same change.
5. Tighten the `messages:listMessages` pagination contract and remove the stray iOS `id` field if needed.
6. Replace `.first()` with `.unique()` only in truly unique lookups and add tests.
7. Add compound indexes for `taskerCategories` and any real production query gaps.
8. Clean up test helper performance issues.
9. Extract shared auth/error helpers.
10. Split large files only after behavior is stable.

## Definition Of Done

- [ ] `convex-doctor` no longer reports any `✖` errors.
- [x] `convex-doctor` no longer reports any `✖` errors.
- [ ] Production iOS flows still work:
  - auth bootstrap
  - profile creation
  - location sync
  - tasker profile read/update
  - messages pagination
  - review eligibility
  - review submission
  - subscription update/cancel/ghost mode
- [x] UI tests and Convex tests pass, or any intentionally deferred failures are documented.
- [ ] No manual changes remain under `convex/_generated/`.
- [x] No manual changes remain under `convex/_generated/`.
- [ ] Any remaining warnings are explicitly accepted as low-priority or false positives with rationale.

Current rollout note:
- Backend production deploy is live and validated.
- Web build and backend test coverage are green against the production Convex URLs.
- iOS app build and unit tests are green against the production configuration.
- Full iOS UI test coverage is not a valid production gate today because helper-backed scenarios depend on `/test-proxy`, and that route is intentionally disabled on production.
- The production-safe UI subset is green when run serially in isolation with its own result bundle.
- The remaining iOS test limitation is operational: do not run overlapping `xcodebuild` UI test sessions against the same simulator/derived-data space.
