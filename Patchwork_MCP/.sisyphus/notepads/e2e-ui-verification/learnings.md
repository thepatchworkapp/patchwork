# E2E UI Verification - Learnings & Conventions

## Project Conventions

### Test Infrastructure
- Playwright config at root: `playwright.config.ts`
- Tests in: `tests/ui/`
- Evidence: `.sisyphus/evidence/{test-name}/`
- Helpers: `tests/ui/helpers/`

### Auth Pattern (from messaging.test.ts)
- Email OTP flow: email entry → OTP code from terminal → verify → profile
- OTP retrieved via: `api.testing.getOtp(email)`
- Test users use pattern: `e2e_{uuid}@test.com`

### Cleanup Requirements
- Only delete @test.com or e2e_ prefixed data
- Use beforeAll/afterAll for setup/cleanup
- UUID-based test run IDs prevent collisions

## Key Files
- `convex/testing.ts` - Testing utilities (add cleanup here)
- `tests/ui/messaging.test.ts` - Reference auth flow
- `tests/ui/helpers/auth.ts` - To be created (Task 2)
- `tests/ui/helpers/cleanup.ts` - To be created (Task 2)
- `tests/ui/smoke.test.ts` - To be created (Task 3)

## Screens to Test
1. SignIn (Email OTP)
2. CreateProfile
3. Profile
4. Categories
5. Messages
6. Chat
7. Jobs
8. Tasker Onboarding

## Deferred Features (DO NOT TEST)
- Typing indicators
- Online presence
- Job completion flow
- Reviews
- Push notifications
