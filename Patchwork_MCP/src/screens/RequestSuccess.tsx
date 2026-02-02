import { CheckCircle } from "lucide-react";
import { Button } from "../components/patchwork/Button";

export function RequestSuccess({ onViewRequests, onHome }: { onViewRequests: () => void; onHome: () => void }) {
  return (
    <div className="min-h-screen bg-white flex flex-col items-center justify-center px-8 text-center">
      <div className="size-20 rounded-full bg-green-100 flex items-center justify-center mb-6">
        <CheckCircle size={40} className="text-[#16A34A]" />
      </div>

      <h1 className="text-neutral-900 mb-4">Request sent!</h1>
      <p className="text-[#6B7280] mb-8 max-w-sm">
        Your request is now visible to 47 Taskers within 25 km. You'll be notified when they respond with quotes.
      </p>

      <div className="w-full max-w-sm space-y-3">
        <Button variant="primary" fullWidth onClick={onViewRequests}>
          View My Requests
        </Button>
        <Button variant="ghost" fullWidth onClick={onHome}>
          Back to Home
        </Button>
      </div>
    </div>
  );
}
