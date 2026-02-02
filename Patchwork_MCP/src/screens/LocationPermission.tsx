import { MapPin } from "lucide-react";
import { Button } from "../components/patchwork/Button";

export function LocationPermission({ onAllow, onSkip }: { onAllow: () => void; onSkip: () => void }) {
  return (
    <div className="min-h-screen bg-white flex flex-col">
      <div className="flex-1 flex flex-col items-center justify-center px-8 text-center">
        <div className="size-20 rounded-full bg-indigo-100 flex items-center justify-center mb-8">
          <MapPin size={40} className="text-[#4F46E5]" />
        </div>
        
        <h1 className="text-neutral-900 mb-4">Allow location access</h1>
        <p className="text-[#6B7280] mb-8 max-w-sm">
          Patchwork uses your location to find service providers within 100 km. We only show your approximate area to Taskers until you confirm a job.
        </p>

        <div className="bg-neutral-50 rounded-lg p-4 mb-8 text-left w-full max-w-sm">
          <label className="flex items-start gap-3">
            <input type="checkbox" className="mt-1" defaultChecked />
            <div>
              <p className="text-neutral-900 mb-1">Enable precise location</p>
              <p className="text-[#6B7280] text-sm">More accurate distance calculations</p>
            </div>
          </label>
        </div>
      </div>

      <div className="p-4 space-y-3">
        <Button variant="primary" fullWidth onClick={onAllow}>
          Allow Location Access
        </Button>
        <Button variant="ghost" fullWidth onClick={onSkip}>
          Not Now
        </Button>
      </div>
    </div>
  );
}
