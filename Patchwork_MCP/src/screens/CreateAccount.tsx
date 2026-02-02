import { signInWithGoogle } from "../lib/auth";
import { Button } from "../components/patchwork/Button";
import { Logo } from "../components/patchwork/Logo";

export function CreateAccount({ onBack }: { onBack: () => void }) {
  const handleGoogleSignIn = async () => {
    try {
      await signInWithGoogle();
    } catch (error) {
      console.error("Google sign in failed:", error);
    }
  };

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <div className="flex-1 px-4 pt-16 flex flex-col">
        <div className="mb-8 text-center flex flex-col items-center">
          <Logo textColor="#15181B" className="w-[223px] h-auto mb-4" />
          <p className="text-[#6B7280] text-center px-4">
            You'll start as a Seeker. You can add a Tasker profile anytime to offer your services.
          </p>
        </div>

        <div className="space-y-3 mb-8">
          <Button variant="secondary" fullWidth onClick={handleGoogleSignIn}>
            <div className="flex items-center justify-center gap-2">
              <span>G</span>
              <span>Continue with Google</span>
            </div>
          </Button>
        </div>

        <p className="text-center text-[#6B7280] text-sm px-4">
          By continuing, you agree to our Terms of Service and Privacy Policy
        </p>

        <div className="mt-auto pb-8">
          <p className="text-center text-[#6B7280]">
            Already have an account?{" "}
            <button onClick={onBack} className="text-[#4F46E5]">
              Sign in
            </button>
          </p>
        </div>
      </div>
    </div>
  );
}
