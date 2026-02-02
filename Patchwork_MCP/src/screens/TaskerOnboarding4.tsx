import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { useState } from "react";

export function TaskerOnboarding4({ onBack, onComplete }: { onBack: () => void; onComplete: () => void }) {
  const [acceptedTerms, setAcceptedTerms] = useState(false);

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="Become a Tasker" onBack={onBack} />

      <div className="flex-1 px-4 pt-6">
        <div className="mb-6">
          <div className="flex items-center gap-2 mb-6">
            <div className="size-8 rounded-full bg-[#16A34A] text-white flex items-center justify-center">✓</div>
            <div className="flex-1 h-1 bg-[#16A34A]" />
            <div className="size-8 rounded-full bg-[#16A34A] text-white flex items-center justify-center">✓</div>
            <div className="flex-1 h-1 bg-[#4F46E5]" />
            <div className="size-8 rounded-full bg-[#4F46E5] text-white flex items-center justify-center">3</div>
          </div>
        </div>

        <h2 className="text-neutral-900 mb-2">Review & accept</h2>
        <p className="text-[#6B7280] mb-6">Final step to complete your Tasker profile</p>

        <div className="space-y-6">
          <div className="border border-neutral-200 rounded-lg p-4">
            <label className="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox"
                checked={acceptedTerms}
                onChange={(e) => setAcceptedTerms(e.target.checked)}
                className="mt-1 size-5 rounded border-neutral-300 text-[#4F46E5] focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-0 cursor-pointer"
              />
              <span className="flex-1 text-neutral-900">
                I agree to the{" "}
                <a href="#" className="text-[#4F46E5] underline">
                  Terms and Conditions
                </a>{" "}
                for Tasker profiles, including maintaining accurate information, providing quality service, and following community guidelines.
              </span>
            </label>
          </div>
        </div>
      </div>

      <div className="p-4 border-t border-neutral-200">
        <Button variant="primary" fullWidth onClick={onComplete} disabled={!acceptedTerms}>
          Complete Setup
        </Button>
      </div>
    </div>
  );
}