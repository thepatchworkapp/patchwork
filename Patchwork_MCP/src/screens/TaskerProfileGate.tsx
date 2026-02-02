import { Briefcase } from "lucide-react";
import { Button } from "../components/patchwork/Button";

export function TaskerProfileGate({ onClose, onComplete }: { onClose: () => void; onComplete: () => void }) {
  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-end" onClick={onClose}>
      <div
        className="bg-white rounded-t-2xl w-full max-w-[390px] mx-auto p-6 pb-8"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="w-12 h-1 bg-neutral-300 rounded-full mx-auto mb-6" />
        
        <div className="text-center mb-6">
          <div className="size-16 rounded-full bg-indigo-100 mx-auto mb-4 flex items-center justify-center">
            <Briefcase size={32} className="text-[#4F46E5]" />
          </div>
          <h2 className="text-neutral-900 mb-2">Finish Tasker profile</h2>
          <p className="text-[#6B7280]">
            Complete your profile to send quotes and accept jobs. Takes 2–3 minutes.
          </p>
        </div>

        <div className="space-y-3">
          <Button variant="primary" fullWidth onClick={onComplete}>
            Complete Profile
          </Button>
          <Button variant="ghost" fullWidth onClick={onClose}>
            Maybe Later
          </Button>
        </div>
      </div>
    </div>
  );
}
