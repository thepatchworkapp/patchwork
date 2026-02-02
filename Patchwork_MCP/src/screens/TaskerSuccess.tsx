import { CheckCircle } from "lucide-react";
import { Button } from "../components/patchwork/Button";

export function TaskerSuccess({ onSubscribe }: { onSubscribe: () => void }) {
  return (
    <div className="min-h-screen bg-white flex flex-col items-center justify-center px-8 text-center">
      <div className="size-20 rounded-full bg-green-100 flex items-center justify-center mb-6">
        <CheckCircle size={40} className="text-[#16A34A]" />
      </div>

      <h1 className="text-neutral-900 mb-4">Your Tasker profile is complete</h1>
      <p className="text-[#6B7280] mb-8 max-w-sm">
        To become discoverable to Seekers in your area, subscribe to a plan.
      </p>

      <div className="w-full max-w-sm">
        <Button variant="primary" fullWidth onClick={onSubscribe}>
          Subscribe
        </Button>
      </div>
    </div>
  );
}