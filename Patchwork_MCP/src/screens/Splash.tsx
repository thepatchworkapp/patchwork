import { Button } from "../components/patchwork/Button";
import { Logo } from "../components/patchwork/Logo";

export function Splash({ onGetStarted }: { onGetStarted: () => void }) {
  return (
    <div className="fixed inset-0 bg-[#4F46E5] flex flex-col items-center justify-between px-8 py-12">
      <div className="flex-1 flex flex-col items-center justify-center">
        {/* Logo/Brand */}
        <div className="text-center flex flex-col items-center">
          <Logo textColor="#FFFFFF" className="w-[280px] h-auto mb-6" />
          <p className="text-indigo-200">
            Connect with local service providers, or list yourself in over 65 categories.
          </p>
        </div>
      </div>

      {/* Get Started Button */}
      <div className="w-full max-w-[390px]">
        <button
          onClick={onGetStarted}
          className="w-full bg-white text-[#4F46E5] px-4 py-3 rounded-lg transition-colors active:bg-neutral-50"
        >
          Get Started
        </button>
      </div>
    </div>
  );
}