import { useState } from "react";
import { signInWithEmailOtp } from "../lib/auth";
import { Input } from "../components/patchwork/Input";
import { Button } from "../components/patchwork/Button";
import { AppBar } from "../components/patchwork/AppBar";

export function EmailEntry({ 
  onBack, 
  onSendCode 
}: { 
  onBack: () => void; 
  onSendCode: (email: string) => void;
}) {
  const [email, setEmail] = useState("");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const validateEmail = (email: string) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const handleSendCode = async () => {
    setError("");
    
    if (!email.trim()) {
      setError("Please enter your email");
      return;
    }
    
    if (!validateEmail(email)) {
      setError("Please enter a valid email address");
      return;
    }
    
    setIsLoading(true);
    try {
      await signInWithEmailOtp(email);
      onSendCode(email);
    } catch (err) {
      setError("Failed to send code. Please try again.");
      console.error("Email OTP error:", err);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar
        onBack={onBack}
        title="Sign In with Email"
      />
      
      <div className="flex-1 px-4 pt-8 flex flex-col">
        <div className="mb-8">
          <h1 className="text-neutral-900 mb-2">Enter your email</h1>
          <p className="text-[#6B7280]">
            We'll send you a verification code to sign in
          </p>
        </div>

        <div className="mb-8">
          <Input
            type="email"
            placeholder="your@email.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            error={error}
          />
        </div>

        <div className="space-y-3">
          <Button 
            variant="primary" 
            fullWidth 
            onClick={handleSendCode}
            disabled={isLoading}
          >
            {isLoading ? "Sending..." : "Send Code"}
          </Button>
          
          <button
            onClick={onBack}
            className="w-full text-[#4F46E5] py-2"
          >
            Back to Sign In
          </button>
        </div>
      </div>
    </div>
  );
}
