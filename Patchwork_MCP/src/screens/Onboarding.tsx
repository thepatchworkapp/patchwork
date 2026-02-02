import { useState } from "react";
import { Button } from "../components/patchwork/Button";
import { MapPin, Bell, Users } from "lucide-react";

export function Onboarding({ onComplete }: { onComplete: () => void }) {
  const [step, setStep] = useState(0);

  const slides = [
    {
      icon: Users,
      title: "Connect with local service providers",
      description: "Find trusted Taskers within 100 km for 65+ categories—from plumbing to tutoring."
    },
    {
      icon: MapPin,
      title: "Real reviews. No ads.",
      description: "Rankings are based on genuine client ratings and proximity—never paid placements."
    },
    {
      icon: Bell,
      title: "Grow your local business",
      description: "Start as a Seeker, add a Tasker profile anytime to offer your own services."
    }
  ];

  const current = slides[step];
  const Icon = current.icon;

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <div className="flex-1 flex flex-col items-center justify-center px-8 text-center">
        <div className="size-20 rounded-full bg-indigo-100 flex items-center justify-center mb-8">
          <Icon size={40} className="text-[#4F46E5]" />
        </div>
        
        <h1 className="text-neutral-900 mb-4">{current.title}</h1>
        <p className="text-[#6B7280] mb-12 max-w-sm">
          {current.description}
        </p>

        <div className="flex gap-2 mb-8">
          {slides.map((_, i) => (
            <div
              key={i}
              className={`h-2 rounded-full transition-all ${
                i === step ? "w-8 bg-[#4F46E5]" : "w-2 bg-neutral-300"
              }`}
            />
          ))}
        </div>
      </div>

      <div className="p-4 space-y-3">
        {step < slides.length - 1 ? (
          <>
            <Button variant="primary" fullWidth onClick={() => setStep(step + 1)}>
              Next
            </Button>
            <Button variant="ghost" fullWidth onClick={onComplete}>
              Skip
            </Button>
          </>
        ) : (
          <Button variant="primary" fullWidth onClick={onComplete}>
            Get Started
            </Button>
        )}
      </div>
    </div>
  );
}
