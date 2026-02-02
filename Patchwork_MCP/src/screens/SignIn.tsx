import { signInWithGoogle } from "../lib/auth";
import { Button } from "../components/patchwork/Button";
import { Logo } from "../components/patchwork/Logo";

export function SignIn({ onCreateAccount, onEmailSignIn }: {
  onCreateAccount: () => void;
  onEmailSignIn?: () => void;
}) {
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
        <div className="mb-12 text-center flex flex-col items-center">
          <Logo textColor="#15181B" className="w-[223px] h-auto mb-4" />
          <p className="text-[#6B7280]">Sign in to continue</p>
        </div>

        <div className="space-y-3 mb-8">
          <Button variant="secondary" fullWidth onClick={handleGoogleSignIn}>
            <div className="flex items-center justify-center gap-2">
              <span>G</span>
              <span>Continue with Google</span>
            </div>
          </Button>
        </div>

        <div className="flex items-center gap-4 mb-8">
          <div className="flex-1 h-[1px] bg-neutral-300"></div>
          <span className="text-[#6B7280] text-sm">or</span>
          <div className="flex-1 h-[1px] bg-neutral-300"></div>
        </div>

        <Button 
          variant="secondary" 
          fullWidth 
          onClick={onEmailSignIn}
        >
          Continue with Email
        </Button>

        <div className="mt-auto pb-8">
          <p className="text-center text-[#6B7280]">
            Don't have an account?{" "}
            <button onClick={onCreateAccount} className="text-[#4F46E5]">
              Create account
            </button>
          </p>
        </div>
      </div>
    </div>
  );
}
