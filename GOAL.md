# Discover Category Analytics Implementation Plan

## Goal

Record category demand from the Discover tab and surface it in the admin panel.

The feature has two analytics signals:

- Category selections: when a user explicitly chooses a specific category in Discover.
- Category search submissions: when a user explicitly submits a category search term.

The admin panel should show category selection counts over 1, 7, and 30 day windows, with rolling daily averages for the 7 and 30 day windows. It should also show submitted category search terms in aggregate.

## Product Decisions

- A category "view" means the user selected that category in Discover.
- The "All categories" option is ignored and should not be tracked.
- A user can count toward a given category at most once per calendar day.
- Search tracking records only explicit search submissions, not every text change.
- Search terms are trimmed, capped, and empty terms are rejected.
- Admin should aggregate search terms by default, but exact submitted terms do not need to be hidden from admins.
- Analytics writes from the iOS app are fire-and-forget. Discover browsing and searching must not fail if analytics recording fails.
- Analytics tables should be included in the admin database reset flow.

## Backend Plan

Add new Convex analytics tables instead of mutating `categories`, since categories are seed/reference data.

Recommended tables:

- `discoverCategoryDailyViews`
  - `categoryId`
  - `categorySlug`
  - `categoryName`
  - `dayKey`
  - `viewCount`
  - `uniqueUserCount`
  - `createdAt`
  - `updatedAt`
  - indexes for category/day and day/category.

- `discoverCategoryUserDailyViews`
  - `userId`
  - `categoryId`
  - `dayKey`
  - `createdAt`
  - unique-style lookup index on user/category/day for deduplication.

- `discoverCategorySearchDailyTerms`
  - `normalizedTerm`
  - `displayTerm`
  - `dayKey`
  - `searchCount`
  - `createdAt`
  - `updatedAt`
  - indexes for term/day and day/search count.

Optional raw event tables are not needed for the first version. Daily aggregate buckets should be the source of truth for admin reporting.

## Backend Mutations

Add a new `analytics.ts` Convex module with public authenticated mutations:

- `recordDiscoverCategorySelection({ categorySlug })`
  - Reject missing or unknown category slugs.
  - Ignore inactive categories.
  - Ignore synthetic/all-categories selections by not accepting null or empty slugs.
  - Resolve the category by slug.
  - Build a server-side `dayKey` from the current timestamp.
  - Check `discoverCategoryUserDailyViews` for an existing user/category/day row.
  - If a row already exists, return a no-op result.
  - If not, insert the dedup row and increment/upsert the daily category bucket.

- `recordDiscoverCategorySearchSubmit({ term })`
  - Trim whitespace.
  - Cap the submitted term length, for example 120 characters.
  - Reject empty terms after trimming.
  - Normalize for aggregation using lowercase plus collapsed internal whitespace.
  - Preserve a display term for admins.
  - Build a server-side `dayKey`.
  - Increment/upsert the daily search-term bucket.

These mutations should return small status objects and should not expose user analytics history.

## Admin Query Plan

Add an admin-only query, likely in `admin.ts`:

- `getDiscoverAnalytics({ limit })`
  - Require current admin auth.
  - Return category rows with:
    - category id
    - category name
    - category slug
    - last 1 day count
    - last 7 day count
    - last 7 day average per day
    - last 30 day count
    - last 30 day average per day
    - unique user counts for the same windows if cheap from the daily buckets.
  - Return top search terms with:
    - display term
    - normalized term
    - last 1 day count
    - last 7 day count
    - last 30 day count
    - last seen day.

The query should read daily aggregate buckets, not scan raw event rows.

## iOS Plan

Update the Discover category sheet in `Patchwork_iOS/Patchwork/Features/Home/HomeView.swift`.

Category selection:

- When a user selects a real category, trigger the analytics mutation after updating the selected category.
- Do not track "All categories".
- Do not block the category selection, sheet dismissal, or search reload on analytics.
- Swallow/log analytics failures locally without presenting an error to the user.

Category search:

- Add explicit submit handling to the category search field.
- Record a search only when the user submits via keyboard search or the explicit magnifying/search action if one is added.
- Do not record every keystroke.
- Do not record empty trimmed terms.
- Fire and forget the analytics mutation.

API wrapper:

- Add typed wrappers in `PatchworkAPI.swift` for the analytics mutations.
- Keep the call sites small and avoid coupling analytics failures to `AppState.presentError`.

## Admin Panel Plan

Update `patchwork-admin/src/react/AdminApp.tsx` to surface analytics.

Recommended UI:

- Add a Discover analytics section to the existing admin overview.
- Show a category demand table:
  - Category
  - 1 day
  - 7 day total
  - 7 day average/day
  - 30 day total
  - 30 day average/day
  - Unique users, if included.
- Show a search demand table:
  - Search term
  - 1 day
  - 7 day
  - 30 day
  - Last seen.

Use neutral labels like "Category selections" rather than "views" unless the UI explicitly defines a view as a category selection.

## Admin Reset Plan

Update the admin reset table list so analytics data is cleared with the rest of application data:

- `discoverCategoryDailyViews`
- `discoverCategoryUserDailyViews`
- `discoverCategorySearchDailyTerms`

Update the reset result type and admin UI copy/counts if the reset flow reports per-table deletion counts.

## Testing And Verification

Backend:

- Add Convex tests for category selection deduplication:
  - same user, same category, same day counts once.
  - same user, different category counts separately.
  - different users, same category counts separately.
  - unknown/inactive category does not create analytics.
  - "All categories" is not recorded.

- Add Convex tests for search submission:
  - trims terms.
  - rejects empty terms.
  - caps long terms.
  - aggregates by normalized term.
  - preserves a display term for admin.

- Add admin query tests for 1, 7, and 30 day windows.
- Add admin reset tests to confirm analytics tables are cleared.

iOS:

- Verify category selection still reloads Discover even if analytics mutation fails.
- Verify "All categories" does not call analytics.
- Verify search submission records only on explicit submit.

Admin:

- Build `patchwork-admin` after adding the admin query contract.
- Confirm empty analytics state renders cleanly.
- Confirm populated daily buckets render correct 1, 7, and 30 day values.

