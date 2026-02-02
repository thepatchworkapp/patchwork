import { Calendar, DollarSign } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Input } from "../components/patchwork/Input";
import { Chip } from "../components/patchwork/Chip";
import { useState } from "react";

export function RequestStep3({ onBack, onNext }: { onBack: () => void; onNext: () => void }) {
  const [timing, setTiming] = useState("flexible");

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="New Request" onBack={onBack} />

      <div className="flex-1 px-4 pt-6">
        <div className="mb-6">
          <div className="flex items-center gap-2 mb-6">
            <div className="size-8 rounded-full bg-[#16A34A] text-white flex items-center justify-center">✓</div>
            <div className="flex-1 h-1 bg-[#16A34A]" />
            <div className="size-8 rounded-full bg-[#16A34A] text-white flex items-center justify-center">✓</div>
            <div className="flex-1 h-1 bg-[#4F46E5]" />
            <div className="size-8 rounded-full bg-[#4F46E5] text-white flex items-center justify-center">3</div>
            <div className="flex-1 h-1 bg-neutral-200" />
            <div className="size-8 rounded-full bg-neutral-200 text-[#6B7280] flex items-center justify-center">4</div>
          </div>
        </div>

        <h2 className="text-neutral-900 mb-2">When and budget?</h2>
        <p className="text-[#6B7280] mb-6">Help Taskers know your timing and budget expectations</p>

        <div className="mb-6">
          <label className="block mb-3 text-neutral-900">When do you need this done?</label>
          <div className="flex flex-wrap gap-2 mb-4">
            <Chip label="Flexible" active={timing === "flexible"} onClick={() => setTiming("flexible")} />
            <Chip label="Within 48h" active={timing === "48h"} onClick={() => setTiming("48h")} />
            <Chip label="This week" active={timing === "week"} onClick={() => setTiming("week")} />
            <Chip label="Specific date" active={timing === "specific"} onClick={() => setTiming("specific")} />
          </div>

          {timing === "specific" && (
            <div className="space-y-3">
              <Input type="date" label="Preferred date" />
              <Input type="time" label="Preferred time" />
            </div>
          )}
        </div>

        <div className="mb-6">
          <Input
            type="text"
            label="Budget (optional)"
            placeholder="$100-150"
          />
          <p className="text-[#6B7280] text-sm mt-2">
            Providing a budget helps Taskers assess if they're a good fit, but the final price is negotiated.
          </p>
        </div>

        <div className="bg-indigo-50 rounded-lg p-4">
          <p className="text-[#4F46E5] mb-2">💡 Pro tip</p>
          <p className="text-[#6B7280] text-sm">
            Being flexible with timing often gets you faster responses and better rates.
          </p>
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
