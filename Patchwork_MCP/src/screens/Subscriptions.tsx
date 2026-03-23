import { Check } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { useEffect, useState } from "react";
import { useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

type TaskerAccessType = "weekly" | "lifetime";

interface SubscriptionsProps {
  onBack: () => void;
  onSubscribe: (accessType: TaskerAccessType) => void;
  onSkip: () => void;
}

const accessOptions: Array<{
  id: TaskerAccessType;
  title: string;
  price: string;
  cadence: string;
  details: string;
  bullets: string[];
}> = [
  {
    id: "weekly",
    title: "Weekly access",
    price: "$1.99",
    cadence: "/week",
    details: "Equivalent to $104/year billed weekly.",
    bullets: [
      "Turn off forced Ghost Mode and appear in Seeker discovery",
      "Manage your discoverability and restore purchases in the App Store",
      "Keep a flexible weekly billing option while Patchwork is greenfield",
    ],
  },
  {
    id: "lifetime",
    title: "Lifetime access",
    price: "$79.99",
    cadence: "one time",
    details: "Permanent tasker access with no renewal.",
    bullets: [
      "Unlock discoverability permanently with one purchase",
      "No renewal cycle or cancellation step to manage later",
      "Best fit if you know you want to stay listed long term",
    ],
  },
];

export function Subscriptions({ onBack, onSubscribe, onSkip }: SubscriptionsProps) {
  const [selectedAccessType, setSelectedAccessType] = useState<TaskerAccessType | null>(null);
  const [showGhostModeModal, setShowGhostModeModal] = useState(false);
  const [isSubscribing, setIsSubscribing] = useState(false);
  const [error, setError] = useState("");

  const taskerProfile = useQuery(api.taskers.getTaskerProfile);
  const updateSubscription = useMutation(api.taskers.updateSubscriptionPlan);
  const hasActiveSubscription = taskerProfile?.hasActiveSubscription ?? false;
  const currentPlan = taskerProfile?.subscriptionPlan ?? "none";
  const currentAccessType = taskerProfile?.subscriptionAccessType as TaskerAccessType | undefined;

  useEffect(() => {
    if (selectedAccessType) {
      return;
    }

    if (currentPlan === "tasker" && currentAccessType) {
      setSelectedAccessType(currentAccessType);
      return;
    }

    if (currentPlan !== "none") {
      setSelectedAccessType("weekly");
    }
  }, [currentAccessType, currentPlan, selectedAccessType]);

  const selectedOption =
    selectedAccessType === null
      ? null
      : accessOptions.find((option) => option.id === selectedAccessType) ?? null;

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="Tasker Access" onBack={onBack} />

      <div className="flex-1 px-4 pt-6 pb-24 overflow-y-auto">
        <p className="text-[#6B7280] mb-6 text-center">
          {hasActiveSubscription
            ? "Switch between weekly billing and lifetime access anytime. Your profile stays discoverable while access is active."
            : "Choose tasker access to turn off forced Ghost Mode and become discoverable."}
        </p>

        {accessOptions.map((option) => (
          <div
            key={option.id}
            className={`bg-white border-2 rounded-2xl p-6 mb-4 cursor-pointer transition-all ${
              selectedAccessType === option.id
                ? "border-[#4F46E5] shadow-lg"
                : "border-neutral-200"
            }`}
            onClick={() => setSelectedAccessType(option.id)}
          >
            <div className="flex items-start justify-between mb-4">
              <div>
                <p className="text-[#6B7280] mb-1">{option.title}</p>
                <p className="text-[#4F46E5] text-3xl">
                  {option.price}
                  <span className="text-xl ml-1">{option.cadence}</span>
                </p>
                <p className="text-[#6B7280] text-sm mt-2">{option.details}</p>
              </div>
              {selectedAccessType === option.id && (
                <div className="size-6 rounded-full bg-[#4F46E5] flex items-center justify-center">
                  <Check size={16} className="text-white" />
                </div>
              )}
            </div>

            <div className="space-y-3">
              {option.bullets.map((bullet) => (
                <div key={bullet} className="flex items-start gap-3">
                  <div className="size-5 rounded-full bg-[#4F46E5] flex items-center justify-center flex-shrink-0 mt-0.5">
                    <Check size={14} className="text-white" />
                  </div>
                  <p className="text-neutral-900">{bullet}</p>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="fixed bottom-0 left-0 right-0 max-w-[390px] mx-auto p-4 bg-white border-t border-neutral-200">
        {error && (
          <div className="mb-3 text-center text-red-500 text-sm">
            {error}
          </div>
        )}
        <button
          onClick={() => {
            if (hasActiveSubscription) {
              onBack();
              return;
            }

            setShowGhostModeModal(true);
          }}
          className="text-[#4F46E5] text-center w-full mb-3 underline"
          disabled={isSubscribing}
        >
          {hasActiveSubscription ? "Keep current access" : "Skip for now"}
        </button>
        <Button
          variant="primary"
          fullWidth
          disabled={!selectedOption || isSubscribing}
          onClick={async () => {
            if (!selectedOption) return;

            setIsSubscribing(true);
            setError("");

            try {
              await updateSubscription({
                plan: "tasker",
                accessType: selectedOption.id,
              });
              onSubscribe(selectedOption.id);
            } catch (err) {
              console.error("Subscription failed:", err);
              setError(err instanceof Error ? err.message : "Failed to subscribe. Please try again.");
              setIsSubscribing(false);
            }
          }}
        >
          {isSubscribing
            ? "Processing..."
            : selectedOption
              ? selectedOption.id === "weekly"
                ? "Activate weekly access"
                : "Unlock lifetime access"
              : "Select an access option"}
        </Button>
      </div>

      {showGhostModeModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-6 max-w-sm w-full">
            <h3 className="text-neutral-900 mb-3 text-center">Ghost Mode</h3>
            <p className="text-[#6B7280] mb-6 text-center">
              Your profile is complete, but you're in Ghost Mode and not discoverable by Seekers until you activate tasker access.
            </p>
            <div className="space-y-3">
              <Button
                variant="primary"
                fullWidth
                onClick={() => {
                  setShowGhostModeModal(false);
                  if (onSkip) onSkip();
                }}
              >
                Ok
              </Button>
              <Button
                variant="secondary"
                fullWidth
                onClick={() => setShowGhostModeModal(false)}
              >
                Activate access
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
