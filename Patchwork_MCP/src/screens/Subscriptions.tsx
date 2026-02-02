import { Check } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { useState } from "react";
import { useMutation } from "convex/react";
import { api } from "../../convex/_generated/api";

interface SubscriptionsProps {
  onBack: () => void;
  onSubscribe: (plan: "basic" | "premium") => void;
  onSkip: () => void;
}

export function Subscriptions({ onBack, onSubscribe, onSkip }: SubscriptionsProps) {
  const [selectedPlan, setSelectedPlan] = useState<"basic" | "premium" | null>(null);
  const [showGhostModeModal, setShowGhostModeModal] = useState(false);
  const [isSubscribing, setIsSubscribing] = useState(false);
  const [error, setError] = useState("");

  const updateSubscription = useMutation(api.taskers.updateSubscriptionPlan);

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="Subscription" onBack={onBack} />

      <div className="flex-1 px-4 pt-6 pb-24 overflow-y-auto">
        <p className="text-[#6B7280] mb-6 text-center">
          You can upgrade or downgrade anytime.
        </p>

        {/* Basic Plan */}
        <div
          className={`bg-white border-2 rounded-2xl p-6 mb-4 cursor-pointer transition-all ${
            selectedPlan === "basic"
              ? "border-[#4F46E5] shadow-lg"
              : "border-neutral-200"
          }`}
          onClick={() => setSelectedPlan("basic")}
        >
          <div className="flex items-start justify-between mb-4">
            <div>
              <p className="text-[#6B7280] mb-1">Basic</p>
              <p className="text-[#4F46E5] text-3xl">
                $7.00<span className="text-xl">/mo</span>
              </p>
            </div>
            {selectedPlan === "basic" && (
              <div className="size-6 rounded-full bg-[#4F46E5] flex items-center justify-center">
                <Check size={16} className="text-white" />
              </div>
            )}
          </div>

          <div className="space-y-3">
            <div className="flex items-start gap-3">
              <div className="size-5 rounded-full bg-[#4F46E5] flex items-center justify-center flex-shrink-0 mt-0.5">
                <Check size={14} className="text-white" />
              </div>
              <p className="text-neutral-900">One category to list your service in</p>
            </div>

            <div className="flex items-start gap-3">
              <div className="size-5 rounded-full bg-[#4F46E5] flex items-center justify-center flex-shrink-0 mt-0.5">
                <Check size={14} className="text-white" />
              </div>
              <p className="text-neutral-900">250 km radius search</p>
            </div>

            <div className="flex items-start gap-3">
              <div className="size-5 rounded-full bg-[#4F46E5] flex items-center justify-center flex-shrink-0 mt-0.5">
                <Check size={14} className="text-white" />
              </div>
              <p className="text-neutral-900">
                <span className="text-[#F59E0B]">Founders</span> badge if first in your category
              </p>
            </div>
          </div>
        </div>

        {/* Premium Plan */}
        <div
          className={`bg-white border-2 rounded-2xl p-6 cursor-pointer transition-all ${
            selectedPlan === "premium"
              ? "border-[#4F46E5] shadow-lg"
              : "border-neutral-200"
          }`}
          onClick={() => setSelectedPlan("premium")}
        >
          <div className="flex items-start justify-between mb-4">
            <div>
              <p className="text-[#6B7280] mb-1">Premium</p>
              <p className="text-[#4F46E5] text-3xl">
                $15.00<span className="text-xl">/mo</span>
              </p>
            </div>
            {selectedPlan === "premium" && (
              <div className="size-6 rounded-full bg-[#4F46E5] flex items-center justify-center">
                <Check size={16} className="text-white" />
              </div>
            )}
          </div>

          <div className="space-y-3">
            <div className="flex items-start gap-3">
              <div className="size-5 rounded-full bg-[#4F46E5] flex items-center justify-center flex-shrink-0 mt-0.5">
                <Check size={14} className="text-white" />
              </div>
              <p className="text-neutral-900">Unlimited categories</p>
            </div>

            <div className="flex items-start gap-3">
              <div className="size-5 rounded-full bg-[#4F46E5] flex items-center justify-center flex-shrink-0 mt-0.5">
                <Check size={14} className="text-white" />
              </div>
              <p className="text-neutral-900">250 km radius search</p>
            </div>

            <div className="flex items-start gap-3">
              <div className="size-5 rounded-full bg-[#4F46E5] flex items-center justify-center flex-shrink-0 mt-0.5">
                <Check size={14} className="text-white" />
              </div>
              <p className="text-neutral-900">Unique searchable pin — Seekers can search your pin number to bring up your profile directly and skip the pool</p>
            </div>

            <div className="flex items-start gap-3">
              <div className="size-5 rounded-full bg-[#4F46E5] flex items-center justify-center flex-shrink-0 mt-0.5">
                <Check size={14} className="text-white" />
              </div>
              <p className="text-neutral-900">Visually distinct profile</p>
            </div>

            <div className="flex items-start gap-3">
              <div className="size-5 rounded-full bg-[#4F46E5] flex items-center justify-center flex-shrink-0 mt-0.5">
                <Check size={14} className="text-white" />
              </div>
              <p className="text-neutral-900">
                <span className="text-[#F59E0B]">Founders</span> badge if first in your category
              </p>
            </div>
          </div>
        </div>
      </div>

       <div className="fixed bottom-0 left-0 right-0 max-w-[390px] mx-auto p-4 bg-white border-t border-neutral-200">
         {error && (
           <div className="mb-3 text-center text-red-500 text-sm">
             {error}
           </div>
         )}
         <button
           onClick={() => setShowGhostModeModal(true)}
           className="text-[#4F46E5] text-center w-full mb-3 underline"
           disabled={isSubscribing}
         >
           Skip for now
         </button>
         <Button
           variant="primary"
           fullWidth
           disabled={!selectedPlan || isSubscribing}
           onClick={async () => {
             if (!selectedPlan) return;
             
             setIsSubscribing(true);
             setError("");
             
             try {
               await updateSubscription({
                 plan: selectedPlan,
               });
               onSubscribe(selectedPlan);
             } catch (err) {
               console.error("Subscription failed:", err);
               setError(err instanceof Error ? err.message : "Failed to subscribe. Please try again.");
               setIsSubscribing(false);
             }
           }}
         >
           {isSubscribing ? "Processing..." : selectedPlan ? `Subscribe to ${selectedPlan === "basic" ? "Basic" : "Premium"}` : "Select a plan"}
         </Button>
       </div>

      {/* Ghost Mode Modal */}
      {showGhostModeModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-6 max-w-sm w-full">
            <h3 className="text-neutral-900 mb-3 text-center">Ghost Mode</h3>
            <p className="text-[#6B7280] mb-6 text-center">
              Your profile is complete, but you're in ghost mode and not discoverable by Seekers until you activate a subscription plan.
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
                variant="outline"
                fullWidth
                onClick={() => setShowGhostModeModal(false)}
              >
                Subscribe
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}