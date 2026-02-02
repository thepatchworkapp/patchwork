import { Bell } from "lucide-react";
import { Button } from "../components/patchwork/Button";

export function NotificationPermission({ onAllow, onSkip }: { onAllow: () => void; onSkip: () => void }) {
  return (
    <div className="min-h-screen bg-white flex flex-col">
      <div className="flex-1 flex flex-col items-center justify-center px-8 text-center">
        <div className="size-20 rounded-full bg-indigo-100 flex items-center justify-center mb-8">
          <Bell size={40} className="text-[#4F46E5]" />
        </div>
        
        <h1 className="text-neutral-900 mb-4">Stay updated</h1>
        <p className="text-[#6B7280] mb-8 max-w-sm">
          Get notified about job updates, new messages, and quote responses.
        </p>

        <div className="space-y-3 mb-8 w-full max-w-sm text-left">
          <div className="flex items-center gap-3 p-3 bg-neutral-50 rounded-lg">
            <div className="size-10 rounded-full bg-white flex items-center justify-center">
              📋
            </div>
            <div>
              <p className="text-neutral-900">Job updates</p>
              <p className="text-[#6B7280] text-sm">Accepted, completed, cancelled</p>
            </div>
          </div>
          
          <div className="flex items-center gap-3 p-3 bg-neutral-50 rounded-lg">
            <div className="size-10 rounded-full bg-white flex items-center justify-center">
              💬
            </div>
            <div>
              <p className="text-neutral-900">New messages</p>
              <p className="text-[#6B7280] text-sm">From Taskers and Seekers</p>
            </div>
          </div>
        </div>
      </div>

      <div className="p-4 space-y-3">
        <Button variant="primary" fullWidth onClick={onAllow}>
          Enable Notifications
        </Button>
        <Button variant="ghost" fullWidth onClick={onSkip}>
          Maybe Later
        </Button>
      </div>
    </div>
  );
}
