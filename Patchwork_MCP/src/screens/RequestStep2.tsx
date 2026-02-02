import { MapPin } from "lucide-react";
import { useState } from "react";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Input } from "../components/patchwork/Input";
import { useUserLocation } from "../hooks/useUserLocation";

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

interface RequestStep2Props {
  onBack: () => void;
  onNext: () => void;
  formData: FormData;
  onFormChange: (data: FormData) => void;
}

export function RequestStep2({ onBack, onNext, formData, onFormChange }: RequestStep2Props) {
  const { requestLocation, isLoading: locationLoading } = useUserLocation();
  const [locationError, setLocationError] = useState("");

  const handleUseCurrentLocation = async () => {
    setLocationError("");
    try {
      await requestLocation();
    } catch (error) {
      setLocationError("Failed to get location. Please enter manually.");
    }
  };

  const isFormValid = formData.address.trim() && formData.city.trim() && formData.province.trim();

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
          
          <button 
            onClick={handleUseCurrentLocation}
            disabled={locationLoading}
            className="flex items-center gap-2 text-[#4F46E5] mb-6 disabled:opacity-50"
          >
            <MapPin size={16} />
            <span>{locationLoading ? "Getting location..." : "Use my current location"}</span>
          </button>

          {locationError && (
            <p className="text-red-600 text-sm mb-4">{locationError}</p>
          )}

          <Input
            label="Address"
            placeholder="123 Main St"
            value={formData.address}
            onChange={(e) => onFormChange({
              ...formData,
              address: e.target.value,
            })}
          />

          <div className="grid grid-cols-2 gap-3 mt-3">
            <Input
              label="City"
              placeholder="Toronto"
              value={formData.city}
              onChange={(e) => onFormChange({
                ...formData,
                city: e.target.value,
              })}
            />
            <Input
              label="Province"
              placeholder="ON"
              value={formData.province}
              onChange={(e) => onFormChange({
                ...formData,
                province: e.target.value,
              })}
            />
          </div>
        </div>

        <div className="bg-neutral-50 rounded-lg p-4">
          <p className="text-neutral-900 mb-2">Search radius: {formData.searchRadius} km</p>
          <p className="text-[#6B7280] text-sm mb-3">
            Taskers within {formData.searchRadius} km can see your request. You can adjust this later.
          </p>
          <div className="flex items-center gap-3">
            <input 
              type="range" 
              min="5" 
              max="100" 
              value={formData.searchRadius}
              onChange={(e) => onFormChange({
                ...formData,
                searchRadius: parseInt(e.target.value),
              })}
              className="flex-1" 
            />
            <span className="text-neutral-900 w-12 text-right">{formData.searchRadius} km</span>
          </div>
        </div>
      </div>

      <div className="p-4 border-t border-neutral-200">
        <Button 
          variant="primary" 
          fullWidth 
          onClick={onNext}
          disabled={!isFormValid}
        >
          Continue
        </Button>
      </div>
    </div>
  );
}
