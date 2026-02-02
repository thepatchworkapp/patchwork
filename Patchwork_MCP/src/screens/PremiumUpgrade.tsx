import { X, Zap } from "lucide-react";
import { Button } from "../components/patchwork/Button";

interface PremiumUpgradeProps {
  onBack: () => void;
  onUpgrade: () => void;
}

export function PremiumUpgrade({ onBack, onUpgrade }: PremiumUpgradeProps) {
  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-end" onClick={onBack}>
      <div 
        className="bg-white rounded-t-2xl w-full max-w-[390px] p-6 animate-slide-up"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex justify-between items-center mb-6">
          <button onClick={onBack} className="text-[#6B7280]">
            <X size={24} />
          </button>
        </div>

        <div className="text-center mb-6">
          <div className="inline-flex items-center justify-center size-16 rounded-full bg-[#4F46E5]/10 mb-4">
            <Zap size={32} className="text-[#4F46E5]" />
          </div>
          <h2 className="text-neutral-900 mb-2">Upgrade to Premium</h2>
          <p className="text-[#6B7280]">
            Multiple service categories require a Premium subscription
          </p>
        </div>

        <div className="bg-neutral-50 rounded-lg p-4 mb-6">
          <h3 className="text-neutral-900 mb-3">Premium Benefits</h3>
          <ul className="space-y-2 text-sm">
            <li className="flex items-start gap-2">
              <span className="text-[#16A34A] mt-0.5">✓</span>
              <span className="text-neutral-900">Unlimited service categories</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#16A34A] mt-0.5">✓</span>
              <span className="text-neutral-900">Priority placement in search results</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#16A34A] mt-0.5">✓</span>
              <span className="text-neutral-900">Advanced analytics and insights</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#16A34A] mt-0.5">✓</span>
              <span className="text-neutral-900">Verified badge on your profile</span>
            </li>
          </ul>
        </div>

        <div className="space-y-3">
          <Button variant="primary" fullWidth onClick={onUpgrade}>
            Upgrade to Premium
          </Button>
          <button
            onClick={onBack}
            className="w-full py-3 text-[#6B7280] text-center"
          >
            Maybe later
          </button>
        </div>
      </div>
    </div>
  );
}