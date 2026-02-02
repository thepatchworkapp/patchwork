import { useState } from "react";
import { useMutation } from "convex/react";
import { api } from "../../convex/_generated/api";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Card } from "../components/patchwork/Card";

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

interface RequestStep4Props {
  onBack: () => void;
  onSubmit: () => void;
  formData: FormData;
  onFormChange: (data: FormData) => void;
}

export function RequestStep4({ onBack, onSubmit, formData, onFormChange }: RequestStep4Props) {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");
  const createJobRequest = useMutation(api.jobRequests.createJobRequest);

  const handleSubmit = async () => {
    setError("");
    setIsSubmitting(true);

    try {
      const timingData = {
        type: formData.timingType,
        specificDate: formData.timingType === "specific_date" ? formData.specificDate : undefined,
        specificTime: formData.timingType === "specific_date" ? formData.specificTime : undefined,
      };

      const budgetData = formData.budgetMin || formData.budgetMax ? {
        min: formData.budgetMin ? Math.round(parseFloat(formData.budgetMin) * 100) : 0,
        max: formData.budgetMax ? Math.round(parseFloat(formData.budgetMax) * 100) : 0,
      } : undefined;

      await createJobRequest({
        categoryId: formData.categoryId as any,
        categoryName: formData.categoryName,
        description: formData.description,
        location: {
          address: formData.address,
          city: formData.city,
          province: formData.province,
          searchRadius: formData.searchRadius,
        },
        timing: timingData,
        budget: budgetData,
      });

      onSubmit();
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to create request";
      setError(message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const timingDisplay = formData.timingType === "asap" 
    ? "ASAP"
    : formData.timingType === "specific_date"
    ? `${formData.specificDate}${formData.specificTime ? ` at ${formData.specificTime}` : ""}`
    : "Flexible";

  const budgetDisplay = formData.budgetMin || formData.budgetMax
    ? `$${formData.budgetMin || "0"}-$${formData.budgetMax || "∞"}`
    : "Not specified";
  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="New Request" onBack={onBack} />

      <div className="flex-1 px-4 pt-6">
        <div className="mb-6">
          <div className="flex items-center gap-2 mb-6">
            <div className="size-8 rounded-full bg-[#16A34A] text-white flex items-center justify-center">✓</div>
            <div className="flex-1 h-1 bg-[#16A34A]" />
            <div className="size-8 rounded-full bg-[#16A34A] text-white flex items-center justify-center">✓</div>
            <div className="flex-1 h-1 bg-[#16A34A]" />
            <div className="size-8 rounded-full bg-[#16A34A] text-white flex items-center justify-center">✓</div>
            <div className="flex-1 h-1 bg-[#4F46E5]" />
            <div className="size-8 rounded-full bg-[#4F46E5] text-white flex items-center justify-center">4</div>
          </div>
        </div>

        <h2 className="text-neutral-900 mb-2">Review your request</h2>
        <p className="text-[#6B7280] mb-6">Make sure everything looks good before sending</p>

        <div className="space-y-4">
          <Card>
            <div className="mb-2">
              <p className="text-[#6B7280] text-sm mb-1">Category</p>
              <p className="text-neutral-900">{formData.categoryName}</p>
            </div>
          </Card>

          <Card>
            <div className="mb-2">
              <p className="text-[#6B7280] text-sm mb-1">Task description</p>
              <p className="text-neutral-900">{formData.description}</p>
            </div>
          </Card>

          <Card>
            <div className="mb-2">
              <p className="text-[#6B7280] text-sm mb-1">Location</p>
              <p className="text-neutral-900">{formData.address}, {formData.city}, {formData.province}</p>
              <p className="text-[#6B7280] text-sm">Search radius: {formData.searchRadius} km</p>
            </div>
          </Card>

          <Card>
            <div className="mb-2">
              <p className="text-[#6B7280] text-sm mb-1">Timing</p>
              <p className="text-neutral-900">{timingDisplay}</p>
            </div>
          </Card>

          <Card>
            <div className="mb-2">
              <p className="text-[#6B7280] text-sm mb-1">Budget</p>
              <p className="text-neutral-900">{budgetDisplay}</p>
            </div>
          </Card>
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-4 mt-6">
            <p className="text-red-700 text-sm">{error}</p>
          </div>
        )}

        <div className="bg-neutral-50 rounded-lg p-4 mt-6">
          <p className="text-neutral-900 mb-2">What happens next?</p>
          <ul className="space-y-2 text-[#6B7280] text-sm">
            <li>• Nearby Taskers (within 25 km) will see your request</li>
            <li>• You'll receive quotes and messages from interested Taskers</li>
            <li>• Review profiles, ratings, and proposed pricing</li>
            <li>• Choose your Tasker and confirm the job</li>
          </ul>
        </div>
      </div>

      <div className="p-4 border-t border-neutral-200">
        <Button 
          variant="primary" 
          fullWidth 
          onClick={handleSubmit}
          disabled={isSubmitting}
        >
          {isSubmitting ? "Sending..." : "Send Request"}
        </Button>
      </div>
    </div>
  );
}
