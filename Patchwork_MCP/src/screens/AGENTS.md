# Screens - AI Agent Guidelines

> 38 screen components using callback-based navigation (NO React Router)

## Navigation Pattern (CRITICAL)

This app does NOT use React Router. All navigation is callback-based:

```tsx
// Every screen receives these props
interface ScreenProps {
  onNavigate: (screen: string) => void;  // Go to screen
  onBack: () => void;                     // Go back in history
}

// Usage
<Button onClick={() => onNavigate("home")}>Home</Button>
<Button onClick={() => onBack()}>Back</Button>
```

**Screen names** are strings defined in `App.tsx`. Common screens:
- `"home"`, `"browse"`, `"messages"`, `"jobs"`, `"profile"`
- `"sign-in"`, `"email-entry"`, `"email-verify"`, `"create-profile"`
- `"tasker-onboarding-1"`, `"tasker-onboarding-2"`, `"tasker-onboarding-4"`
- `"request-step-1"`, `"request-step-2"`, `"request-step-3"`, `"request-step-4"`

## Standard Screen Layout

```tsx
export function MyScreen({ onNavigate, onBack }: Props) {
  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      {/* AppBar at top */}
      <AppBar 
        title="Screen Title"
        showBack
        onBack={onBack}
      />
      
      {/* Content with standard padding */}
      <div className="px-4 py-6">
        {/* Screen content */}
      </div>
      
      {/* BottomNav for main screens */}
      <BottomNav activeTab="home" onNavigate={onNavigate} />
    </div>
  );
}
```

## Screen Categories

| Category | Screens | Notes |
|----------|---------|-------|
| **Auth Flow** | SignIn, EmailEntry, EmailVerify, CreateProfile | Linear flow |
| **Main Tabs** | Home, Browse, Messages, Jobs, Profile | BottomNav |
| **Tasker Onboarding** | TaskerOnboarding1, 2, 4, TaskerSuccess | Multi-step form |
| **Request Flow** | RequestStep1-4, RequestSuccess | Task request wizard |
| **Unified** | HomeUnified, BrowseUnified | Role-based UI |

## State Management

### Local State (Most Screens)
```tsx
const [isLoading, setIsLoading] = useState(false);
const [error, setError] = useState("");
```

### Convex Integration (3 screens)
```tsx
// CreateProfile.tsx, TaskerOnboarding2.tsx, Profile.tsx
const generateUploadUrl = useMutation(api.files.generateUploadUrl);
const userData = useQuery(api.users.getCurrentUser);
```

### Props-Based State (Onboarding)
```tsx
// Parent (App.tsx) owns state, passes down
<TaskerOnboarding1
  displayName={displayName}
  onDisplayNameChange={setDisplayName}
  selectedCategories={selectedCategories}
  onCategoriesChange={setSelectedCategories}
  onNavigate={handleNavigate}
/>
```

## Modal Pattern

```tsx
// State
const [showModal, setShowModal] = useState(false);

// Modal JSX (at end of component)
{showModal && (
  <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
    <div className="bg-white rounded-2xl mx-4 max-w-md w-full p-6">
      {/* Modal content */}
      <Button onClick={() => setShowModal(false)}>Close</Button>
    </div>
  </div>
)}
```

**Bottom sheet variant:**
```tsx
<div className="fixed inset-0 bg-black/50 z-50 flex items-end">
  <div className="bg-white rounded-t-2xl w-full p-6">
    {/* Bottom sheet content */}
  </div>
</div>
```

## Role-Based UI

```tsx
// Many screens show different UI for Seekers vs Taskers
interface Props {
  isTasker: boolean;
}

// Conditional rendering
{isTasker ? (
  <TaskerView />
) : (
  <SeekerView />
)}

// Lock pattern for non-taskers
{!isTasker && (
  <div className="absolute inset-0 bg-white/80 flex items-center justify-center">
    <Lock className="size-6 text-neutral-400" />
    <span>Upgrade to Tasker to access</span>
  </div>
)}
```

## Component Imports

```tsx
// ALWAYS import from patchwork/
import { AppBar } from "@/components/patchwork/AppBar";
import { Button } from "@/components/patchwork/Button";
import { Card } from "@/components/patchwork/Card";
import { Avatar } from "@/components/patchwork/Avatar";
import { Badge } from "@/components/patchwork/Badge";
import { BottomNav } from "@/components/patchwork/BottomNav";

// Icons from lucide-react
import { Search, MapPin, Star, Lock, Camera } from "lucide-react";
```

## Known Complexity Issues

| File | Lines | Issue | Recommendation |
|------|-------|-------|----------------|
| **Profile.tsx** | 665 | 15 props, 211-line inline modal | Extract CategoryModal |
| **Chat.tsx** | 493 | 38+ useState, 4 similar handlers | Extract useProposalHandler |
| **HomeSwipe.tsx** | ~400 | Complex swipe interactions | Keep isolated |

## Query Optimization Patterns (CRITICAL)

### Server-Side Filtering (MANDATORY)

When a screen has tabs or filters (role, status, category), pass the filter value **as a query argument** to the backend. NEVER fetch all data then filter in the component.

```tsx
// CORRECT — pass filter to server
const conversations = useQuery(api.conversations.listConversations, {
  role: activeTab,   // "seeker" | "tasker"
  limit: 50,
});

// FORBIDDEN — fetch all, filter in component
const allConversations = useQuery(api.conversations.listConversations);
const filtered = allConversations?.filter(c => 
  activeTab === "seeker" ? c.seekerId === user._id : c.taskerId === user._id
);
```

**Screens already optimized (follow these as reference)**:
| Screen | Query | Filter Args |
|--------|-------|-------------|
| `Messages.tsx` | `listConversations` | `role`, `limit` |
| `Jobs.tsx` | `listJobs` | `statusGroup` ("active" \| "completed") |
| `HomeSwipe.tsx` | `searchTaskers` | `categorySlug`, `radiusKm`, location coords |

### Avoid Unnecessary Query Dependencies

Don't call `getCurrentUser` just to get the user's ID for filtering — if the backend query already resolves the user from auth context, skip it.

```tsx
// BAD — extra query just to get userId for client-side filtering
const currentUser = useQuery(api.users.getCurrentUser);
const conversations = useQuery(api.conversations.listConversations);
const filtered = conversations?.filter(c => c.seekerId === currentUser?._id);

// GOOD — server handles auth + filtering internally
const conversations = useQuery(api.conversations.listConversations, { role: "seeker", limit: 50 });
```

### Category Slug Generation

When generating slugs from category names for query args, use proper slugification:

```tsx
// CORRECT
const slug = categoryName.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
// "Pest Control" → "pest-control"

// WRONG
const slug = categoryName.toLowerCase();
// "Pest Control" → "pest control" (breaks index lookup)
```

### ~~`usePaginatedQuery` for Chat~~ — RESOLVED

`useChat` hook uses `usePaginatedQuery` with `initialNumItems: 25`. Chat.tsx has a "Load more" button wired to `loadMoreMessages`.

## Anti-Patterns to Avoid

1. **Adding more useState to Chat.tsx** - Already has 38+, needs refactoring
2. **Inline modals >100 lines** - Extract to separate component
3. **Hardcoding screen names** - Use constants or App.tsx types
4. **Missing loading states** - Always show loading UI for async operations
5. **No error handling** - Add try/catch for Convex calls
6. **Client-side filtering of Convex queries** - See Query Optimization above. Always server-side
7. **Fetching `getCurrentUser` just for filtering** - Let the backend resolve user from auth context
8. **Hardcoding category lists** - All categories come from `api.categories.listCategories`. NEVER define inline arrays of category names

## File Upload Pattern

```tsx
const generateUploadUrl = useMutation(api.files.generateUploadUrl);

const handleUpload = async (file: File) => {
  setIsLoading(true);
  try {
    const uploadUrl = await generateUploadUrl();
    const response = await fetch(uploadUrl, {
      method: "POST",
      body: file,
    });
    const { storageId } = await response.json();
    // Use storageId for saving
  } catch (error) {
    setError("Upload failed");
  } finally {
    setIsLoading(false);
  }
};
```

## Tab Navigation (Internal)

```tsx
// Messages.tsx, Browse.tsx
const [activeTab, setActiveTab] = useState<"seeker" | "tasker">("seeker");

<div className="flex border-b">
  <button
    className={activeTab === "seeker" ? "border-b-2 border-indigo-600" : ""}
    onClick={() => setActiveTab("seeker")}
  >
    Seeker
  </button>
  <button
    className={activeTab === "tasker" ? "border-b-2 border-indigo-600" : ""}
    onClick={() => setActiveTab("tasker")}
  >
    Tasker
  </button>
</div>
```
