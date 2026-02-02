import { useState } from "react";
import { Input } from "../components/patchwork/Input";
import { Button } from "../components/patchwork/Button";
import { AppBar } from "../components/patchwork/AppBar";
import { Mail } from "lucide-react";

export function ResetPassword({ onBack, onSent }: { onBack: () => void; onSent: () => void }) {
  const [email, setEmail] = useState("");

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="Reset Password" onBack={onBack} />
      
      <div className="flex-1 px-4 pt-8">
        <div className="flex flex-col items-center text-center mb-8">
          <div className="size-16 rounded-full bg-indigo-100 flex items-center justify-center mb-4">
            <Mail size={32} className="text-[#4F46E5]" />
          </div>
          <p className="text-[#6B7280]">
            Enter your email and we'll send you a link to reset your password.
          </p>
        </div>

        <div className="space-y-4 mb-6">
          <Input
            type="email"
            label="Email"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>

        <Button variant="primary" fullWidth onClick={onSent}>
          Send Reset Link
        </Button>
      </div>
    </div>
  );
}
