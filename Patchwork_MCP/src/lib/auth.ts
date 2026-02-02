import { createAuthClient } from "better-auth/react";
import { emailOTPClient } from "better-auth/client/plugins";
import {
  convexClient,
  crossDomainClient,
} from "@convex-dev/better-auth/client/plugins";

export const authClient = createAuthClient({
  baseURL: import.meta.env.VITE_CONVEX_SITE_URL,
  plugins: [emailOTPClient(), convexClient(), crossDomainClient()],
});

export const { useSession, signIn, signOut } = authClient;

export const useAuth = () => {
  const session = useSession();
  return {
    isAuthenticated: !!session.data?.user,
    isLoading: session.isPending,
    user: session.data?.user ?? null,
  };
};

export const signInWithGoogle = () => {
  return authClient.signIn.social({
    provider: "google",
    callbackURL: import.meta.env.VITE_SITE_URL || window.location.origin,
  });
};

export const signInWithEmailOtp = async (email: string) => {
  return authClient.emailOtp.sendVerificationOtp({ email, type: "sign-in" });
};

export const verifyEmailOtp = async (email: string, otp: string) => {
  return authClient.signIn.emailOtp({ email, otp });
};
