# Patchwork iOS Agent Guide

This file captures critical project learnings and operating rules for any coding agent working in `Patchwork_iOS`.

## Product Truths

- iOS target app for current product is `ltd.ddga.patchwork`.
- App Store Connect app ID for current product is `6759272540` (`Patchwork: Freelance`).
- Do not use old app slug `com.agk.patchwork` (legacy app, wrong target for current releases).
- Backend must remain unchanged; iOS must conform to existing Convex + Better Auth behavior.

## Core UX/Flow Constraints

- Match web PoC (`Patchwork_MCP`) and Figma intent 1:1. Do not invent screens or actions.
- Navigation model is callback-based (not React Router semantics).
- For tabs/filters (role/status/category), pass filter values to backend query arguments.
- Never fetch all data and filter client-side when backend query filtering exists.
- Categories must come from `api.categories.listCategories`; never hardcode inline category lists.
- Include accessibility labels/identifiers for key controls and auth flow elements.

## Auth/OTP Learnings

- OTP flow issues previously seen: `Unexpected response`, `Missing or null Origin`, intermittent `Invalid origin`.
- Fix patterns that proved necessary:
  - Preserve and forward Better Auth cookie headers (`Set-Better-Auth-Cookie` / `Better-Auth-Cookie`).
  - Harden Origin handling and trusted-origin fallback behavior for Convex token exchange.
  - Avoid URLSession cookie bleed between auth attempts; isolate or explicitly manage cookie propagation.
- Keep regression tests for OTP/cookie/origin behavior green before release.

## Build/Test Expectations

- Use `xcodebuild` / `xcodebuildmcp` for simulator validation and UI testing.
- Typical simulator target used in this repo: iPhone 16 simulator id `1A925AF9-A76F-4BA6-86C3-0B56D5FBF786`.
- Run both unit and UI tests after significant changes.

## Release/TestFlight Learnings

- Current TestFlight build successfully configured on correct app:
  - Build ID: `fda6bc32-95c4-4560-910a-373687d61c38`
  - Pre-release version: `1.0.0`
  - Build number: `1`
- Group created and used on correct app:
  - `App Store Connect Users` (group id `634375e4-7876-47f3-ab1c-0065dd92eae1`)
- Export compliance can block assignability:
  - Symptom: `MISSING_EXPORT_COMPLIANCE`, build not assignable.
  - Resolution: create and assign App Encryption Declaration via ASC CLI.
- If ASC upload says bundle version already used, increment `CFBundleVersion` (`CURRENT_PROJECT_VERSION`).

## Icon/Metadata Submission Requirements

- Ensure app icon asset catalog includes required iOS icons (including iPhone 120x120 and iPad 152x152) plus marketing icon.
- Ensure `CFBundleIconName` is present and points to `AppIcon`.
- Keep icon and plist settings in project config stable to avoid ITMS-90022/90023/90713 rejections.

## Project Config Notes

- Xcode project is generated via XcodeGen from `project.yml`.
- If build metadata/plist behavior changes, regenerate with:
  - `xcodegen generate`
- Keep release-relevant settings aligned:
  - `MARKETING_VERSION`
  - `CURRENT_PROJECT_VERSION`
  - `ASSETCATALOG_COMPILER_APPICON_NAME`
  - `CFBundleIconName`

## Working Agreement for Agents

- Verify app slug and app ID before any ASC/TestFlight action.
- Prefer explicit checks before release commands:
  - `asc apps get --id 6759272540`
  - `asc testflight beta-groups list --app 6759272540`
  - `asc builds list --app 6759272540`
- Before finalizing release work, confirm:
  - Build processing state is valid.
  - Export compliance is resolved.
  - Target group has assigned build.
  - Intended testers are present in the group.
