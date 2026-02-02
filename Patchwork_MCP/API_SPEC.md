# Patchwork API Specification

> **Generated from Figma Dev UI Analysis**  
> This document defines the API contract for the Patchwork backend based on mock data patterns found in the frontend UI.

---

## Table of Contents

1. [Overview](#overview)
2. [Data Models](#data-models)
3. [Authentication Endpoints](#authentication-endpoints)
4. [User Endpoints](#user-endpoints)
5. [Tasker Endpoints](#tasker-endpoints)
6. [Job Request Endpoints](#job-request-endpoints)
7. [Job/Booking Endpoints](#jobbooking-endpoints)
8. [Messaging Endpoints](#messaging-endpoints)
9. [Proposal Endpoints](#proposal-endpoints)
10. [Review Endpoints](#review-endpoints)
11. [Subscription Endpoints](#subscription-endpoints)
12. [Category Endpoints](#category-endpoints)
13. [Search & Discovery Endpoints](#search--discovery-endpoints)

---

## Overview

### Platform Roles

| Role | Description |
|------|-------------|
| **Seeker** | Default role. Users who post job requests and hire taskers |
| **Tasker** | Users who provide services. Requires subscription to be discoverable |

### Key Business Rules

1. All users start as Seekers
2. Users can optionally become Taskers (dual role)
3. Taskers require a subscription (Basic $7/mo or Premium $15/mo) to be discoverable
4. Taskers without subscription enter "Ghost Mode" (profile complete but invisible)
5. Basic subscription: 1 category, 250km radius
6. Premium subscription: Unlimited categories, unique PIN, enhanced profile visibility
7. Search radius: 1-250km configurable
8. Proposals can be sent, countered, accepted, or declined

---

## Data Models

### User

```typescript
interface User {
  id: string;
  email: string;
  name: string;
  photo?: string;
  phone?: string;
  memberSince: string; // ISO date
  location: {
    city: string;
    province: string;
    coordinates?: {
      lat: number;
      lng: number;
    };
    address?: string;
  };
  roles: {
    isSeeker: boolean;
    isTasker: boolean;
  };
  seekerInfo?: SeekerProfile;
  taskerInfo?: TaskerProfile;
  settings: {
    notificationsEnabled: boolean;
    locationEnabled: boolean;
  };
  createdAt: string;
  updatedAt: string;
}
```

### SeekerProfile

```typescript
interface SeekerProfile {
  jobsPosted: number;
  completedJobs: number;
  rating: number; // 1-5 scale
  favouriteTaskers: string[]; // tasker user IDs
  savedAddresses: Address[];
}

interface Address {
  id: string;
  label: string; // "Home", "Work", etc.
  address: string;
  city: string;
  province: string;
  postalCode: string;
  coordinates: {
    lat: number;
    lng: number;
  };
  isDefault: boolean;
}
```

### TaskerProfile

```typescript
interface TaskerProfile {
  displayName: string;
  bio?: string;
  categories: TaskerCategory[];
  rating: number; // 1-5 scale, aggregated
  reviewCount: number;
  completedJobs: number;
  responseTime: string; // e.g., "< 1 hour"
  verified: boolean;
  subscriptionPlan: "none" | "basic" | "premium";
  subscriptionExpiresAt?: string;
  ghostMode: boolean; // true = not discoverable
  premiumPin?: string; // Premium only - unique searchable PIN
  foundersBadge?: {
    category: string;
    awardedAt: string;
  };
}

interface TaskerCategory {
  id: string;
  categoryId: string;
  categoryName: string;
  bio: string;
  rateType: "hourly" | "fixed";
  hourlyRate?: number; // cents
  fixedRate?: number; // cents
  serviceRadius: number; // km (1-250)
  photos: string[]; // up to 10 URLs
  stats: {
    rating: number;
    reviewCount: number;
    completedJobs: number;
  };
  createdAt: string;
  updatedAt: string;
}
```

### Category

```typescript
interface Category {
  id: string;
  name: string;
  slug: string;
  icon?: string;
  description?: string;
  isActive: boolean;
}

// Predefined categories from UI:
const CATEGORIES = [
  "Plumbing",
  "Electrical", 
  "Handyman",
  "Cleaning",
  "Moving",
  "Painting",
  "Gardening",
  "Pest Control",
  "Appliance Repair",
  "HVAC",
  "IT Support",
  "Tutoring",
  "House Cleaning",
  "Lawn Care",
  "Furniture Assembly"
];
```

### JobRequest

```typescript
interface JobRequest {
  id: string;
  seekerId: string;
  category: string;
  description: string;
  location: {
    address: string;
    city: string;
    province: string;
    coordinates: {
      lat: number;
      lng: number;
    };
    searchRadius: number; // km
  };
  timing: {
    type: "flexible" | "within_48h" | "this_week" | "specific";
    specificDate?: string; // ISO date
    specificTime?: string; // HH:mm
  };
  budget?: {
    min: number; // cents
    max: number; // cents
  };
  photos?: string[];
  status: "open" | "in_progress" | "completed" | "cancelled";
  createdAt: string;
  updatedAt: string;
}
```

### Job (Booked/Active Job)

```typescript
interface Job {
  id: string;
  requestId?: string; // original request if applicable
  seekerId: string;
  taskerId: string;
  category: string;
  description: string;
  rate: number; // cents
  rateType: "hourly" | "fixed";
  startDate: string; // ISO date
  completedDate?: string;
  status: "pending" | "in_progress" | "completed" | "cancelled" | "disputed";
  notes?: string;
  proposalId: string;
  seekerReviewId?: string;
  taskerReviewId?: string;
  createdAt: string;
  updatedAt: string;
}
```

### Message & Conversation

```typescript
interface Conversation {
  id: string;
  participants: {
    seekerId: string;
    taskerId: string;
  };
  jobRequestId?: string;
  jobId?: string;
  lastMessageAt: string;
  createdAt: string;
}

interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  type: "text" | "proposal" | "system";
  content: string;
  proposalId?: string; // if type === "proposal"
  readAt?: string;
  createdAt: string;
}
```

### Proposal

```typescript
interface Proposal {
  id: string;
  conversationId: string;
  senderId: string;
  receiverId: string;
  jobRequestId?: string;
  rate: number; // cents
  rateType: "hourly" | "flat";
  startDateTime: string; // ISO datetime
  notes?: string;
  status: "pending" | "accepted" | "declined" | "countered" | "expired";
  counterProposalId?: string; // if this is a counter
  previousProposalId?: string; // if countering another proposal
  createdAt: string;
  updatedAt: string;
}
```

### Review

```typescript
interface Review {
  id: string;
  jobId: string;
  reviewerId: string;
  revieweeId: string;
  reviewerRole: "seeker" | "tasker";
  rating: number; // 1-5
  text: string;
  category: string;
  createdAt: string;
}
```

### Subscription

```typescript
interface Subscription {
  id: string;
  userId: string;
  plan: "basic" | "premium";
  status: "active" | "cancelled" | "past_due" | "expired";
  currentPeriodStart: string;
  currentPeriodEnd: string;
  cancelAtPeriodEnd: boolean;
  stripeSubscriptionId?: string;
  createdAt: string;
  updatedAt: string;
}

// Pricing
const SUBSCRIPTION_PLANS = {
  basic: {
    priceMonthly: 700, // $7.00 in cents
    categoryLimit: 1,
    searchRadius: 250,
    features: ["One category", "250km radius", "Founders badge eligibility"]
  },
  premium: {
    priceMonthly: 1500, // $15.00 in cents
    categoryLimit: null, // unlimited
    searchRadius: 250,
    uniquePin: true,
    features: [
      "Unlimited categories",
      "250km radius", 
      "Unique searchable PIN",
      "Visually distinct profile",
      "Founders badge eligibility"
    ]
  }
};
```

---

## Authentication Endpoints

### POST /auth/signup
Create new user account (starts as Seeker).

**Request:**
```json
{
  "provider": "email" | "google" | "apple",
  "email": "user@example.com",
  "password": "...", // only for email
  "token": "..." // OAuth token for google/apple
}
```

**Response:** `201 Created`
```json
{
  "user": User,
  "session": { "token": "...", "expiresAt": "..." }
}
```

### POST /auth/signin
Sign in existing user.

**Request:**
```json
{
  "provider": "email" | "google" | "apple",
  "email": "user@example.com",
  "password": "...", // only for email
  "token": "..." // OAuth token for google/apple
}
```

### POST /auth/email/send-code
Send verification code to email (passwordless login).

**Request:**
```json
{
  "email": "user@example.com"
}
```

### POST /auth/email/verify
Verify email code.

**Request:**
```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

### POST /auth/password/reset
Request password reset.

**Request:**
```json
{
  "email": "user@example.com"
}
```

### POST /auth/signout
Sign out current session.

---

## User Endpoints

### GET /users/me
Get current user profile.

**Response:**
```json
{
  "user": User
}
```

### PATCH /users/me
Update current user profile.

**Request:**
```json
{
  "name": "Jenny Mabel",
  "photo": "https://...",
  "location": {
    "city": "Toronto",
    "province": "ON"
  }
}
```

### POST /users/me/profile
Create user profile after signup.

**Request:**
```json
{
  "name": "Jenny Mabel",
  "photo": "...",
  "location": {
    "city": "Toronto",
    "province": "ON"
  }
}
```

### PATCH /users/me/settings
Update user settings.

**Request:**
```json
{
  "notificationsEnabled": true,
  "locationEnabled": true
}
```

### GET /users/me/addresses
List saved addresses.

### POST /users/me/addresses
Add new address.

### DELETE /users/me/addresses/:id
Remove saved address.

---

## Tasker Endpoints

### POST /users/me/tasker
Activate tasker role (begin onboarding).

**Request:**
```json
{
  "displayName": "JM Plumbing & Repairs"
}
```

### PATCH /users/me/tasker
Update tasker profile.

**Request:**
```json
{
  "displayName": "JM Plumbing & Repairs",
  "ghostMode": false
}
```

### POST /users/me/tasker/categories
Add a category to tasker profile.

**Request:**
```json
{
  "categoryId": "plumbing",
  "bio": "Licensed plumber with 10+ years experience...",
  "rateType": "hourly",
  "hourlyRate": 8500, // $85.00 in cents
  "serviceRadius": 25,
  "photos": ["https://..."]
}
```

### PATCH /users/me/tasker/categories/:categoryId
Update category settings.

### DELETE /users/me/tasker/categories/:categoryId
Remove category from profile.

### GET /taskers/:id
Get public tasker profile.

**Response:**
```json
{
  "tasker": {
    "id": "...",
    "displayName": "Alex Chen",
    "photo": "...",
    "verified": true,
    "categories": [...],
    "rating": 4.9,
    "reviewCount": 127,
    "completedJobs": 243,
    "responseTime": "< 1 hour",
    "memberSince": "2024-01"
  }
}
```

### GET /taskers/:id/reviews
Get reviews for a tasker.

**Query params:**
- `category`: Filter by category
- `limit`: Number of reviews (default 10)
- `cursor`: Pagination cursor

---

## Job Request Endpoints

### POST /requests
Create a new job request.

**Request:**
```json
{
  "category": "Plumbing",
  "description": "Kitchen sink is leaking...",
  "location": {
    "address": "123 Main St",
    "city": "Toronto",
    "province": "ON",
    "coordinates": { "lat": 43.65, "lng": -79.38 },
    "searchRadius": 25
  },
  "timing": {
    "type": "within_48h"
  },
  "budget": {
    "min": 10000,
    "max": 15000
  }
}
```

### GET /requests
List user's job requests (as seeker).

**Query params:**
- `status`: "open" | "in_progress" | "completed" | "cancelled"
- `limit`: Number of requests
- `cursor`: Pagination cursor

### GET /requests/:id
Get job request details.

### PATCH /requests/:id
Update job request.

### DELETE /requests/:id
Cancel/delete job request.

---

## Job/Booking Endpoints

### GET /jobs
List user's jobs (as seeker or tasker).

**Query params:**
- `role`: "seeker" | "tasker"
- `status`: "in_progress" | "completed"
- `limit`: Number of jobs
- `cursor`: Pagination cursor

**Response:**
```json
{
  "jobs": [
    {
      "id": "1",
      "taskerName": "Alex Chen",
      "taskerAvatar": "...",
      "category": "Plumbing",
      "rate": 8500,
      "rateType": "hourly",
      "startDate": "2024-12-18",
      "notes": "Kitchen sink repair - bringing own tools",
      "status": "in_progress"
    }
  ],
  "nextCursor": "..."
}
```

### GET /jobs/:id
Get job details.

### PATCH /jobs/:id
Update job (mark complete, cancel, etc.)

**Request:**
```json
{
  "status": "completed"
}
```

---

## Messaging Endpoints

### GET /conversations
List user's conversations.

**Query params:**
- `role`: "seeker" | "tasker" (filter by which role the user is in)
- `limit`: Number of conversations
- `cursor`: Pagination cursor

**Response:**
```json
{
  "conversations": [
    {
      "id": "...",
      "otherUser": {
        "id": "...",
        "name": "Alex Chen",
        "photo": "..."
      },
      "lastMessage": "I can come by tomorrow at 2pm",
      "lastMessageAt": "2024-12-15T10:30:00Z",
      "unreadCount": 2
    }
  ]
}
```

### GET /conversations/:id
Get conversation details.

### GET /conversations/:id/messages
Get messages in a conversation.

**Query params:**
- `limit`: Number of messages
- `cursor`: Pagination cursor (for older messages)

### POST /conversations/:id/messages
Send a message.

**Request:**
```json
{
  "type": "text",
  "content": "Hi! Yes, 2pm tomorrow works great."
}
```

### POST /conversations
Start a new conversation.

**Request:**
```json
{
  "taskerId": "...",
  "jobRequestId": "...", // optional
  "initialMessage": "Hi! I saw your profile..."
}
```

### PATCH /conversations/:id/read
Mark conversation as read.

---

## Proposal Endpoints

### POST /proposals
Send a proposal.

**Request:**
```json
{
  "conversationId": "...",
  "rate": 8500,
  "rateType": "hourly",
  "startDateTime": "2024-12-16T14:00:00Z",
  "notes": "I'll bring my own tools"
}
```

### POST /proposals/:id/counter
Counter a proposal.

**Request:**
```json
{
  "rate": 7500,
  "rateType": "hourly",
  "startDateTime": "2024-12-17T10:00:00Z",
  "notes": "Can we do morning instead?"
}
```

### POST /proposals/:id/accept
Accept a proposal (creates a Job).

**Response:**
```json
{
  "proposal": Proposal,
  "job": Job
}
```

### POST /proposals/:id/decline
Decline a proposal.

---

## Review Endpoints

### POST /reviews
Create a review after job completion.

**Request:**
```json
{
  "jobId": "...",
  "rating": 5,
  "text": "Excellent work! Fixed the leak quickly..."
}
```

### GET /reviews
Get reviews.

**Query params:**
- `userId`: Reviews for a specific user
- `jobId`: Review for a specific job
- `role`: "seeker" | "tasker" (reviews received in this role)

---

## Subscription Endpoints

### GET /subscriptions/plans
Get available subscription plans.

**Response:**
```json
{
  "plans": [
    {
      "id": "basic",
      "name": "Basic",
      "priceMonthly": 700,
      "features": [...]
    },
    {
      "id": "premium",
      "name": "Premium", 
      "priceMonthly": 1500,
      "features": [...]
    }
  ]
}
```

### GET /subscriptions/current
Get current user's subscription.

### POST /subscriptions
Create a subscription.

**Request:**
```json
{
  "plan": "basic" | "premium",
  "paymentMethodId": "pm_..."
}
```

### PATCH /subscriptions/:id
Update subscription (upgrade/downgrade).

**Request:**
```json
{
  "plan": "premium"
}
```

### DELETE /subscriptions/:id
Cancel subscription (at period end).

---

## Category Endpoints

### GET /categories
List all available categories.

**Response:**
```json
{
  "categories": [
    { "id": "plumbing", "name": "Plumbing", "icon": "wrench" },
    { "id": "electrical", "name": "Electrical", "icon": "zap" },
    ...
  ]
}
```

---

## Search & Discovery Endpoints

### GET /search/taskers
Search for taskers (Seeker's discovery view).

**Query params:**
- `category`: Filter by category (optional, "all" by default)
- `lat`: User's latitude
- `lng`: User's longitude
- `radius`: Search radius in km (1-250)
- `limit`: Number of results
- `cursor`: Pagination cursor

**Response:**
```json
{
  "taskers": [
    {
      "id": "...",
      "name": "Alex Chen",
      "photo": "...",
      "category": "Plumbing",
      "rating": 4.9,
      "reviewCount": 127,
      "price": "$85/hr",
      "distance": "3.2 km",
      "verified": true,
      "bio": "Licensed plumber with 10+ years...",
      "completedJobs": 243
    }
  ],
  "nextCursor": "..."
}
```

### GET /search/taskers/pin/:pin
Search tasker by premium PIN (Premium subscribers only).

**Response:**
```json
{
  "tasker": TaskerPublicProfile
}
```

---

## Real-time Events (WebSocket / Convex Subscriptions)

The following should be real-time subscriptions:

1. **Conversations list** - New messages, unread counts
2. **Messages in a conversation** - New messages appear instantly
3. **Proposal status changes** - Accepted/declined/countered
4. **Job status changes** - Started/completed
5. **New job requests** (for taskers) - When seekers post in their category/radius

---

## Error Responses

All endpoints return errors in this format:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human readable message",
    "details": { ... } // optional additional info
  }
}
```

Common error codes:
- `UNAUTHORIZED` - Not authenticated
- `FORBIDDEN` - Not authorized for this action
- `NOT_FOUND` - Resource not found
- `VALIDATION_ERROR` - Invalid input
- `SUBSCRIPTION_REQUIRED` - Action requires active subscription
- `CATEGORY_LIMIT_REACHED` - Basic plan limited to 1 category

---

## Notes for Convex Implementation

1. **Authentication**: Use `better-auth` plugin for Convex
2. **Real-time**: All list/detail queries should be Convex subscriptions
3. **Geospatial**: Use Convex's built-in geospatial features or a search index
4. **Payments**: Integrate Stripe via Convex actions for subscriptions
5. **File Storage**: Use Convex file storage for photos/avatars
6. **Rate limiting**: Implement for proposal sending, message sending
