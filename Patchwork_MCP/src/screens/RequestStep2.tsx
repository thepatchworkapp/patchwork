import { MapPin } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Input } from "../components/patchwork/Input";

export function RequestStep2({ onBack, onNext }: { onBack: () => void; onNext: () => void }) {
  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="New Request" onBack={onBack} />

      <div className="flex-1 px-4 pt-6">
        <div className="mb-6">
          <div className="flex items-center gap-2 mb-6">
            <div className="size-8 rounded-full bg-[#16A34A] text-white flex items-center justify-center">✓</div>
            <div className="flex-1 h-1 bg-[#4F46E5]" />
            <div className="size-8 rounded-full bg-[#4F46E5] text-white flex items-center justify-center">2</div>
            <div className="flex-1 h-1 bg-neutral-200" />
            <div className="size-8 rounded-full bg-neutral-200 text-[#6B7280] flex items-center justify-center">3</div>
            <div className="flex-1 h-1 bg-neutral-200" />
            <div className="size-8 rounded-full bg-neutral-200 text-[#6B7280] flex items-center justify-center">4</div>
          </div>
        </div>

        <h2 className="text-neutral-900 mb-2">Where is the task?</h2>
        <p className="text-[#6B7280] mb-6">Your exact address is only shared when you confirm a Tasker</p>

        <div className="mb-6">
          <div className="h-48 bg-neutral-200 rounded-lg mb-4 flex items-center justify-center">
            <MapPin size={32} className="text-[#6B7280]" />
          </div>
          
          <button className="flex items-center gap-2 text-[#4F46E5] mb-6">
            <MapPin size={16} />
            <span>Use my current location</span>
          </button>

          <Input
            label="Address"
            placeholder="123 Main St, Toronto, ON"
          />
        </div>

        <div className="bg-neutral-50 rounded-lg p-4">
          <p className="text-neutral-900 mb-2">Search radius: 25 km</p>
          <p className="text-[#6B7280] text-sm mb-3">
            Taskers within 100 km can see your request. You can adjust this later.
          </p>
          <div className="flex items-center gap-3">
            <input type="range" min="5" max="100" defaultValue="25" className="flex-1" />
            <span className="text-neutral-900">25 km</span>
          </div>
        </div>
      </div>

      <div className="p-4 border-t border-neutral-200">
        <Button variant="primary" fullWidth onClick={onNext}>
          Continue
        </Button>
      </div>
    </div>
  );
}
