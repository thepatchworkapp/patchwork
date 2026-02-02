import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Input } from "../components/patchwork/Input";
import { Chip } from "../components/patchwork/Chip";

interface FormData {
  categoryId: string;
  categoryName: string;
  description: string;
  address: string;
  city: string;
  province: string;
  searchRadius: number;
  timingType: "asap" | "specific_date" | "flexible";
  specificDate: string;
  specificTime: string;
  budgetMin: string;
  budgetMax: string;
}

interface RequestStep3Props {
  onBack: () => void;
  onNext: () => void;
  formData: FormData;
  onFormChange: (data: FormData) => void;
}

export function RequestStep3({ onBack, onNext, formData, onFormChange }: RequestStep3Props) {

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
            <Chip 
              label="Flexible" 
              active={formData.timingType === "flexible"} 
              onClick={() => onFormChange({
                ...formData,
                timingType: "flexible",
                specificDate: "",
                specificTime: "",
              })} 
            />
            <Chip 
              label="ASAP" 
              active={formData.timingType === "asap"} 
              onClick={() => onFormChange({
                ...formData,
                timingType: "asap",
                specificDate: "",
                specificTime: "",
              })} 
            />
            <Chip 
              label="Specific date" 
              active={formData.timingType === "specific_date"} 
              onClick={() => onFormChange({
                ...formData,
                timingType: "specific_date",
              })} 
            />
          </div>

          {formData.timingType === "specific_date" && (
            <div className="space-y-3">
              <Input 
                type="date" 
                label="Preferred date"
                value={formData.specificDate}
                onChange={(e) => onFormChange({
                  ...formData,
                  specificDate: e.target.value,
                })}
              />
              <Input 
                type="time" 
                label="Preferred time"
                value={formData.specificTime}
                onChange={(e) => onFormChange({
                  ...formData,
                  specificTime: e.target.value,
                })}
              />
            </div>
          )}
        </div>

        <div className="mb-6">
          <label className="block mb-3 text-neutral-900">Budget (optional)</label>
          <div className="grid grid-cols-2 gap-3">
            <Input
              type="number"
              placeholder="Min ($)"
              value={formData.budgetMin}
              onChange={(e) => onFormChange({
                ...formData,
                budgetMin: e.target.value,
              })}
            />
            <Input
              type="number"
              placeholder="Max ($)"
              value={formData.budgetMax}
              onChange={(e) => onFormChange({
                ...formData,
                budgetMax: e.target.value,
              })}
            />
          </div>
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
