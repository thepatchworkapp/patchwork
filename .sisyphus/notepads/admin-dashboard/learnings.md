# User Detail Implementation

## Overview
Implemented `UserDetail.tsx` in `patchwork-admin/src/pages/`.
This page displays comprehensive user information, including:
- Basic user info (name, email, roles, location)
- Seeker profile stats
- Tasker profile stats and categories
- Job history (seeker and tasker)
- Reviews (given and received)

## Key Features
- Uses `api.admin.getUserDetail` to fetch all data in one query.
- Uses `api.files.getUrl` to fetch user photo.
- Collapsible sections for better organization.
- Formatting for currency and dates.
- Loading and error states.
- Clean UI with Tailwind CSS and Lucide icons.

## Dependencies
- `patchwork-admin`
- `Patchwork_MCP/convex` (for API and Types)

## Next Steps
- Integrate into the main navigation (e.g., from User List).
- Add tests.

## User List Implementation

### UserList Page Implementation
- Created `UserList.tsx` using `useQuery` from Convex.
- Implemented client-side search filtering (simpler than backend filter for this scale).
- Implemented "Load More" pagination by increasing the `limit` arg in state.
- **Critical Fix**: Cross-project imports (importing `Patchwork_MCP` files into `patchwork-admin`) caused `tsc -b` failures due to strictness mismatches.
  - **Solution**: Used `import { anyApi } from "convex/server"; const api = anyApi as any;` to reference backend queries without triggering deep compilation of the other project.
  - **Solution**: Used `import type` for types like `Id` to prevent runtime code inclusion.
- Integrated `UserList` and `UserDetail` into `App.tsx` with simple state-based navigation (`selectedUserId`).
