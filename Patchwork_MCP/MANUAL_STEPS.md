# Patchwork Manual Setup Steps

This document outlines the human-required setup actions that must be completed before the Patchwork implementation can begin.

## Section 1: Account Setup

Before starting development, ensure you have accounts with the following services:

1.  **Convex**: Create an account at [https://convex.dev](https://convex.dev). This will host the database, backend functions, and authentication plugin.
2.  **Stripe**: Create a developer account at [https://stripe.com](https://stripe.com). You will use this for handling subscriptions and payments.
3.  **Google Cloud Console**: Create a project at [https://console.cloud.google.com/](https://console.cloud.google.com/) to manage Google OAuth credentials.
4.  **Apple Developer**: Create an account at [https://developer.apple.com/](https://developer.apple.com/) to set up Sign in with Apple.

---

## Section 2: OAuth Credentials

### Google OAuth Setup

1.  Go to the [Google Cloud Console](https://console.cloud.google.com/).
2.  Navigate to **APIs & Services > Credentials**.
3.  Click **Create Credentials > OAuth client ID**.
4.  Select **Web application** as the application type.
5.  Add the following:
    *   **Authorized JavaScript origins**: `http://localhost:3000` (and your production URL later).
    *   **Authorized redirect URIs**: `http://localhost:3000/api/auth/callback/google`
6.  Copy the **Client ID** and **Client Secret** for your environment variables.

### Apple Sign In Setup

1.  Go to the [Apple Developer Portal](https://developer.apple.com/).
2.  Navigate to **Certificates, Identifiers & Profiles > Identifiers**.
3.  Create a new **App ID** if you don't have one, and enable **Sign In with Apple**.
4.  Create a **Services ID**.
5.  Configure the Services ID with:
    *   **Identifier**: Usually `com.yourdomain.patchwork.auth`.
    *   **Return URLs**: `http://localhost:3000/api/auth/callback/apple`
6.  Generate a **Private Key** (AuthKey) and download it.
7.  Note your **Team ID**, **Client ID** (Services ID identifier), and **Key ID**.

---

## Section 3: Stripe Configuration

1.  **Create Products**:
    *   In the Stripe Dashboard, go to **Products** and create two products:
        *   **Basic Plan**: (e.g., $9.99/month)
        *   **Premium Plan**: (e.g., $19.99/month)
    *   Note the **Price IDs** (starting with `price_...`) for both.
2.  **Set Up Webhooks**:
    *   Go to **Developers > Webhooks**.
    *   Add an endpoint.
    *   **Endpoint URL**: `https://<your-convex-deployment-name>.convex.site/stripe-webhook` (You will get this URL after running `npx convex dev`).
    *   **Select events to listen to**: `checkout.session.completed`, `customer.subscription.deleted`.
    *   Copy the **Webhook Secret** (starting with `whsec_...`).

---

## Section 4: Environment Variables

Create a `.env.local` file in the project root (`Patchwork_MCP/`) and populate it with the following values. Refer to `.env.example` for the structure.

| Variable | Description | Source |
| :--- | :--- | :--- |
| `CONVEX_DEPLOYMENT` | Your Convex project deployment ID | `npx convex dev` |
| `VITE_CONVEX_URL` | Convex backend URL | `npx convex dev` |
| `BETTER_AUTH_SECRET` | Random 32+ character string | Generate manually |
| `BETTER_AUTH_URL` | Auth server URL | `http://localhost:3000` |
| `VITE_BETTER_AUTH_URL` | Auth server URL for frontend | `http://localhost:3000` |
| `GOOGLE_CLIENT_ID` | Google OAuth Client ID | Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | Google OAuth Client Secret | Google Cloud Console |
| `APPLE_CLIENT_ID` | Apple Services ID identifier | Apple Developer Portal |
| `APPLE_CLIENT_SECRET` | Apple Generated Client Secret | Generated via Apple Private Key |
| `STRIPE_SECRET_KEY` | Stripe Restricted or Secret Key | Stripe Dashboard |
| `STRIPE_WEBHOOK_SECRET` | Stripe Webhook Signing Secret | Stripe Webhook Settings |
| `STRIPE_PRICE_BASIC` | Price ID for the Basic plan | Stripe Products |
| `STRIPE_PRICE_PREMIUM` | Price ID for the Premium plan | Stripe Products |
| `APP_URL` | Base application URL | `http://localhost:3000` |

---

## Section 5: Convex Setup

1.  **Initialize Convex**:
    ```bash
    npx convex dev
    ```
    *   This will prompt you to log in to Convex and create a new project.
    *   It will automatically create the `convex/` folder and generate necessary types.
2.  **Deployment**:
    *   For staging/preview: `npx convex deploy --preview`
    *   For production: `npx convex deploy`

---

## Section 6: Vercel Deployment

1.  **Import Project**: Link your GitHub repository to Vercel.
2.  **Configure Environment Variables**:
    *   Copy all variables from your `.env.local` to the Vercel project settings (**Settings > Environment Variables**).
    *   Ensure `BETTER_AUTH_URL`, `VITE_BETTER_AUTH_URL`, and `APP_URL` reflect your Vercel production or preview domain (e.g., `https://patchwork.vercel.app`).
3.  **Domain Configuration**:
    *   Add your custom domain if applicable.
    *   Update OAuth "Authorized redirect URIs" in Google and Apple dashboards to include your production domain.
