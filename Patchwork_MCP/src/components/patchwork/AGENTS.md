# Patchwork Components - AI Agent Guidelines

> 10 custom application-specific components (lightweight, no Radix UI)

## Component Overview

| Component | Purpose | Key Props |
|-----------|---------|-----------|
| `AppBar.tsx` | Top navigation bar | `title`, `showBack`, `onBack`, `actions` |
| `BottomNav.tsx` | Tab navigation | `activeTab`, `onNavigate` |
| `Button.tsx` | Action button | `variant`, `fullWidth`, `disabled` |
| `Card.tsx` | Content container | `children`, `className` |
| `Avatar.tsx` | User image | `src`, `size`, `initials` |
| `Badge.tsx` | Status indicator | `variant`, `children` |
| `Input.tsx` | Form input | Standard input props |
| `Select.tsx` | Dropdown select | Standard select props |
| `Textarea.tsx` | Multi-line input | Standard textarea props |
| `Checkbox.tsx` | Toggle input | Standard checkbox props |

## Styling Approach

**Patchwork uses inline Tailwind with hardcoded colors** (different from ui/ components):

```tsx
// PATCHWORK PATTERN (this folder)
className={`bg-[#4F46E5] text-white px-4 py-2 rounded-lg ${fullWidth ? "w-full" : ""}`}

// UI PATTERN (../ui/) - DO NOT MIX
className={cn(buttonVariants({ variant, size }), className)}
```

## Color Palette (Hardcoded)

```tsx
// Primary
"#4F46E5"  // Indigo - buttons, links, active states

// Status
"#16A34A"  // Green - success
"#DC2626"  // Red - error, destructive
"#D97706"  // Amber - warning

// Neutral
"#6B7280"  // Gray - secondary text
"#F3F4F6"  // Light gray - backgrounds
```

## Button Component

```tsx
interface ButtonProps {
  variant?: "primary" | "secondary" | "ghost" | "destructive";
  fullWidth?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  children: React.ReactNode;
  type?: "button" | "submit";
}

// Usage
<Button variant="primary" fullWidth onClick={handleSubmit}>
  Continue
</Button>

<Button variant="ghost" onClick={onBack}>
  Cancel
</Button>
```

## Avatar Component

```tsx
interface AvatarProps {
  src?: string;
  size?: "sm" | "md" | "lg" | "xl";
  initials?: string;  // Fallback when no image
}

// Sizes
// sm: 32px, md: 40px, lg: 56px, xl: 80px

// Usage
<Avatar src={user.photo} size="lg" initials="JD" />
```

## Badge Component

```tsx
interface BadgeProps {
  variant?: "default" | "success" | "warning" | "error";
  children: React.ReactNode;
}

// Usage
<Badge variant="success">Verified</Badge>
<Badge variant="warning">Pending</Badge>
```

## AppBar Component

```tsx
interface AppBarProps {
  title?: string;
  showBack?: boolean;
  onBack?: () => void;
  showMenu?: boolean;
  onMenu?: () => void;
  actions?: React.ReactNode;
}

// Usage
<AppBar 
  title="Profile"
  showBack
  onBack={onBack}
  actions={<Button variant="ghost">Edit</Button>}
/>
```

## BottomNav Component

```tsx
interface BottomNavProps {
  activeTab: "home" | "browse" | "messages" | "jobs" | "profile";
  onNavigate: (tab: string) => void;
}

// Usage (main screens only)
<BottomNav activeTab="home" onNavigate={onNavigate} />
```

## Card Component

```tsx
// Simple wrapper with shadow and rounded corners
<Card className="p-4">
  <h3>Title</h3>
  <p>Content</p>
</Card>
```

## Input Components

```tsx
// All follow standard HTML patterns
<Input 
  type="email"
  placeholder="Enter email"
  value={email}
  onChange={(e) => setEmail(e.target.value)}
/>

<Textarea
  rows={4}
  placeholder="Description"
  value={bio}
  onChange={(e) => setBio(e.target.value)}
/>

<Select value={category} onChange={(e) => setCategory(e.target.value)}>
  <option value="">Select category</option>
  <option value="cleaning">Cleaning</option>
</Select>

<Checkbox 
  checked={agreed}
  onChange={(e) => setAgreed(e.target.checked)}
/>
```

## When to Use patchwork/ vs ui/

| Use patchwork/ | Use ui/ |
|----------------|---------|
| Simple, app-specific buttons | Complex dialogs, popovers |
| Mobile app bars, bottom nav | Dropdowns with keyboard nav |
| Basic cards, avatars, badges | Accessible form primitives |
| Quick styling needed | Dark mode support needed |

## Inconsistencies to Be Aware Of

1. **No dark mode** - Patchwork components don't support dark mode
2. **Hardcoded colors** - Unlike ui/, colors are inline hex values
3. **No CVA** - No type-safe variants, just string conditionals
4. **No data-slot** - No semantic attributes for CSS targeting

## Adding New Components

Follow this pattern:

```tsx
// NewComponent.tsx
import React from "react";

interface NewComponentProps {
  variant?: "default" | "alt";
  children: React.ReactNode;
  className?: string;
}

export function NewComponent({
  variant = "default",
  children,
  className = "",
}: NewComponentProps) {
  const variants = {
    default: "bg-white border border-neutral-200",
    alt: "bg-neutral-50",
  };
  
  return (
    <div className={`rounded-lg p-4 ${variants[variant]} ${className}`}>
      {children}
    </div>
  );
}
```
