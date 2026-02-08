import { useState } from "react";
import { useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Id } from "../../convex/_generated/dataModel";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Input } from "../components/patchwork/Input";
import { Plus } from "lucide-react";

interface TaskerOnboarding2Props {
  onBack: () => void;
  onNext: (data: { bio: string; rateType: "hourly" | "fixed"; hourlyRate: string; fixedRate: string; serviceRadius: number; photos: string[] }) => void;
}

export function TaskerOnboarding2({ onBack, onNext }: TaskerOnboarding2Props) {
  const generateUploadUrl = useMutation(api.files.generateUploadUrl);
  
  const [serviceRadius, setServiceRadius] = useState(50);
  const [hourlyRate, setHourlyRate] = useState("");
  const [fixedRate, setFixedRate] = useState("");
  const [rateType, setRateType] = useState<"hourly" | "fixed" | "both">("hourly");
  const [bio, setBio] = useState("");
  const [yearsExperience, setYearsExperience] = useState("");
  const [categoryPhotos, setCategoryPhotos] = useState<string[]>([]);

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="Become a Tasker" onBack={onBack} />

      <div className="flex-1 px-4 pt-6 pb-24 overflow-y-auto">
        <div className="mb-6">
          <div className="flex items-center gap-2 mb-6">
            <div className="size-8 rounded-full bg-[#4F46E5] text-white flex items-center justify-center">1</div>
            <div className="flex-1 h-1 bg-[#4F46E5]" />
            <div className="size-8 rounded-full bg-[#4F46E5] text-white flex items-center justify-center">2</div>
            <div className="flex-1 h-1 bg-neutral-200" />
            <div className="size-8 rounded-full bg-neutral-200 text-[#6B7280] flex items-center justify-center">3</div>
          </div>
        </div>

        <h2 className="text-neutral-900 mb-2">Service area & pricing</h2>
        <p className="text-[#6B7280] mb-6">Set your rates and reach</p>

        <div className="space-y-6">
          {/* Pricing Type Selection */}
          <div>
            <label className="block mb-3 text-neutral-900">
              Pricing type
            </label>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setRateType("hourly")}
                className={`flex-1 px-4 py-3 rounded-lg border transition-colors ${
                  rateType === "hourly" || rateType === "both"
                    ? "border-[#4F46E5] bg-[#4F46E5]/5 text-[#4F46E5]"
                    : "border-neutral-200 text-[#6B7280]"
                }`}
              >
                Hourly rate
              </button>
              <button
                type="button"
                onClick={() => setRateType("fixed")}
                className={`flex-1 px-4 py-3 rounded-lg border transition-colors ${
                  rateType === "fixed" || rateType === "both"
                    ? "border-[#4F46E5] bg-[#4F46E5]/5 text-[#4F46E5]"
                    : "border-neutral-200 text-[#6B7280]"
                }`}
              >
                Fixed rate
              </button>
              <button
                type="button"
                onClick={() => setRateType("both")}
                className={`flex-1 px-4 py-3 rounded-lg border transition-colors ${
                  rateType === "both"
                    ? "border-[#4F46E5] bg-[#4F46E5]/5 text-[#4F46E5]"
                    : "border-neutral-200 text-[#6B7280]"
                }`}
              >
                Both
              </button>
            </div>
          </div>

          {/* Hourly Rate */}
          {(rateType === "hourly" || rateType === "both") && (
            <div>
              <label className="block mb-3 text-neutral-900">
                Hourly rate
              </label>
              <div className="relative">
                <span className="absolute left-4 top-1/2 -translate-y-1/2 text-neutral-900">$</span>
                <Input
                  type="number"
                  placeholder="0.00"
                  value={hourlyRate}
                  onChange={(e) => setHourlyRate(e.target.value)}
                  className="pl-8"
                />
              </div>
              <p className="text-[#6B7280] text-sm mt-2">
                Your hourly rate for this service
              </p>
            </div>
          )}

          {/* Fixed Rate */}
          {(rateType === "fixed" || rateType === "both") && (
            <div>
              <label className="block mb-3 text-neutral-900">
                Fixed rate
              </label>
              <div className="relative">
                <span className="absolute left-4 top-1/2 -translate-y-1/2 text-neutral-900">$</span>
                <Input
                  type="number"
                  placeholder="0.00"
                  value={fixedRate}
                  onChange={(e) => setFixedRate(e.target.value)}
                  className="pl-8"
                />
              </div>
              <p className="text-[#6B7280] text-sm mt-2">
                Your fixed project rate for this service
              </p>
            </div>
          )}

          {/* Years of Experience */}
          <div>
            <label className="block mb-3 text-neutral-900">
              Years of experience
            </label>
            <Input
              type="number"
              placeholder="e.g., 5"
              value={yearsExperience}
              onChange={(e) => setYearsExperience(e.target.value)}
            />
          </div>

          {/* Bio */}
          <div>
            <label className="block mb-3 text-neutral-900">
              Bio for this category
            </label>
            <textarea
              placeholder="Tell Seekers about your experience and expertise in this category..."
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              rows={4}
              maxLength={500}
              className="w-full px-4 py-3 border border-neutral-200 rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:border-transparent text-neutral-900 placeholder:text-[#9CA3AF]"
            />
            <p className="text-[#6B7280] text-sm mt-2">
              {bio.length}/500 characters
            </p>
          </div>

          {/* Service Radius */}
          <div>
            <label className="block mb-3 text-neutral-900">
              Service radius: {serviceRadius} km
            </label>
            <div className="relative px-2">
              <input
                type="range"
                min="1"
                max="250"
                value={serviceRadius}
                onChange={(e) => setServiceRadius(Number(e.target.value))}
                className="w-full h-2 bg-neutral-200 rounded-lg appearance-none cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:size-5 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-[#4F46E5] [&::-moz-range-thumb]:size-5 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:bg-[#4F46E5] [&::-moz-range-thumb]:border-0"
              />
              <div className="flex justify-between mt-2">
                <span className="text-[#6B7280] text-sm">1 km</span>
                <span className="text-[#6B7280] text-sm">250 km</span>
              </div>
            </div>
            <p className="text-[#6B7280] text-sm mt-2">
              How far you're willing to travel for jobs
            </p>
          </div>

          {/* Category Photos */}
          <div>
            <label className="block mb-3 text-neutral-900">
              Photos for this category (up to 10)
            </label>
            <p className="text-[#6B7280] text-sm mb-3">
              Showcase your work to attract more clients
            </p>
            <div className="grid grid-cols-3 gap-3">
              {categoryPhotos.map((storageId, index) => (
                <PhotoPreview
                  key={index}
                  storageId={storageId as Id<"_storage">}
                  onRemove={() => setCategoryPhotos(categoryPhotos.filter((_, i) => i !== index))}
                  index={index}
                />
              ))}
              {categoryPhotos.length < 10 && (
                <button
                  type="button"
                  onClick={async () => {
                    const input = document.createElement("input");
                    input.type = "file";
                    input.accept = "image/*";
                    input.onchange = async (e) => {
                      const file = (e.target as HTMLInputElement).files?.[0];
                      if (file) {
                        // 1. Get upload URL (validates type + size server-side)
                        const uploadUrl = await generateUploadUrl({
                          contentType: file.type,
                          fileSize: file.size,
                        });
                        
                        // 2. Upload file
                        const response = await fetch(uploadUrl, {
                          method: "POST",
                          headers: { "Content-Type": file.type },
                          body: file,
                        });
                        const { storageId } = await response.json();
                        
                        // 3. Store ID
                        setCategoryPhotos([...categoryPhotos, storageId]);
                      }
                    };
                    input.click();
                  }}
                  className="aspect-square bg-neutral-100 rounded-lg flex items-center justify-center border-2 border-dashed border-neutral-300 hover:border-[#4F46E5] hover:bg-[#4F46E5]/5 transition-colors"
                >
                  <div className="text-center">
                    <Plus size={24} className="text-[#6B7280] mx-auto mb-1" />
                    <p className="text-xs text-[#6B7280]">Add photo</p>
                  </div>
                </button>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="fixed bottom-0 left-0 right-0 max-w-[390px] mx-auto p-4 bg-white border-t border-neutral-200">
        <Button variant="primary" fullWidth onClick={() => onNext({
          bio,
          rateType: rateType === "both" ? "hourly" : rateType,
          hourlyRate,
          fixedRate,
          serviceRadius,
          photos: categoryPhotos,
        })}>
          Continue
        </Button>
      </div>
    </div>
  );
}

function PhotoPreview({ storageId, onRemove, index }: { storageId: Id<"_storage">; onRemove: () => void; index: number }) {
  const url = useQuery(api.files.getUrl, { storageId });
  
  if (!url) {
    return (
      <div className="aspect-square bg-neutral-100 rounded-lg flex items-center justify-center">
        <div className="text-xs text-[#6B7280]">Loading...</div>
      </div>
    );
  }
  
  return (
    <div className="relative aspect-square bg-neutral-100 rounded-lg overflow-hidden">
      <img
        src={url}
        alt={`Category photo ${index + 1}`}
        className="w-full h-full object-cover"
      />
      <button
        type="button"
        onClick={onRemove}
        className="absolute top-1 right-1 size-6 rounded-full bg-black/60 text-white flex items-center justify-center text-xs"
      >
        ✕
      </button>
    </div>
  );
}