import { useState } from "react";
import { verifyEmailOtp, signInWithEmailOtp } from "../lib/auth";
import { Button } from "../components/patchwork/Button";
import { AppBar } from "../components/patchwork/AppBar";
import {
  InputOTP,
  InputOTPGroup,
  InputOTPSlot,
} from "../components/ui/input-otp";

export function EmailVerify({ 
  email,
  onBack, 
  onVerify,
  onResendCode,
  onBackToSignIn
}: { 
  email: string;
  onBack: () => void; 
  onVerify: (code: string) => void;
  onResendCode: () => void;
  onBackToSignIn: () => void;
}) {
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const handleVerify = async () => {
    setError("");
    
    if (code.length !== 6) {
      setError("Please enter the 6-digit code");
      return;
    }
    
    setIsLoading(true);
    try {
      await verifyEmailOtp(email, code);
      onVerify(code);
    } catch (err) {
      setError("Invalid code. Please try again.");
      console.error("Verify error:", err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleResend = async () => {
    setCode("");
    setError("");
    try {
      await signInWithEmailOtp(email);
      onResendCode();
    } catch (err) {
      setError("Failed to resend code.");
    }
  };

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar
        onBack={onBack}
        title="Verify Email"
      />
      
      <div className="flex-1 px-4 pt-8 flex flex-col">
        <div className="mb-8">
          <h1 className="text-neutral-900 mb-2">Check your email</h1>
          <p className="text-[#6B7280]">
            We sent a code to <span className="font-medium text-neutral-900">{email}</span>
          </p>
        </div>

        <div className="mb-8">
          <label className="block mb-4 text-neutral-900">
            Enter verification code
          </label>
          <div className="flex justify-center">
            <InputOTP
              maxLength={6}
              value={code}
              onChange={(value: string) => {
                setCode(value);
                setError("");
              }}
            >
              <InputOTPGroup className="gap-2">
                <InputOTPSlot 
                  index={0} 
                  className="w-12 h-12 border-2 border-neutral-300 rounded-lg text-center text-lg focus:border-[#4F46E5] focus:ring-2 focus:ring-[#4F46E5]/20"
                />
                <InputOTPSlot 
                  index={1} 
                  className="w-12 h-12 border-2 border-neutral-300 rounded-lg text-center text-lg focus:border-[#4F46E5] focus:ring-2 focus:ring-[#4F46E5]/20"
                />
                <InputOTPSlot 
                  index={2} 
                  className="w-12 h-12 border-2 border-neutral-300 rounded-lg text-center text-lg focus:border-[#4F46E5] focus:ring-2 focus:ring-[#4F46E5]/20"
                />
                <InputOTPSlot 
                  index={3} 
                  className="w-12 h-12 border-2 border-neutral-300 rounded-lg text-center text-lg focus:border-[#4F46E5] focus:ring-2 focus:ring-[#4F46E5]/20"
                />
                <InputOTPSlot 
                  index={4} 
                  className="w-12 h-12 border-2 border-neutral-300 rounded-lg text-center text-lg focus:border-[#4F46E5] focus:ring-2 focus:ring-[#4F46E5]/20"
                />
                <InputOTPSlot 
                  index={5} 
                  className="w-12 h-12 border-2 border-neutral-300 rounded-lg text-center text-lg focus:border-[#4F46E5] focus:ring-2 focus:ring-[#4F46E5]/20"
                />
              </InputOTPGroup>
            </InputOTP>
          </div>
          {error && (
            <p className="mt-3 text-[#DC2626] text-center text-sm">{error}</p>
          )}
        </div>

        <div className="space-y-4">
          <Button 
            variant="primary" 
            fullWidth 
            onClick={handleVerify}
            disabled={code.length !== 6 || isLoading}
          >
            {isLoading ? "Verifying..." : "Verify Code"}
          </Button>
          
          <div className="flex flex-col items-center gap-2">
            <button
              onClick={handleResend}
              className="text-[#4F46E5] py-2"
            >
              Resend Code
            </button>
            
            <button
              onClick={onBackToSignIn}
              className="text-[#4F46E5] py-2"
            >
              Back to Sign In
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
