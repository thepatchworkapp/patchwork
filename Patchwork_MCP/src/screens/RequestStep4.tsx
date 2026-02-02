import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Card } from "../components/patchwork/Card";

export function RequestStep4({ onBack, onSubmit }: { onBack: () => void; onSubmit: () => void }) {
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
              <p className="text-neutral-900">Plumbing</p>
            </div>
          </Card>

          <Card>
            <div className="mb-2">
              <p className="text-[#6B7280] text-sm mb-1">Task description</p>
              <p className="text-neutral-900">
                Kitchen sink is leaking under the counter. Water drips constantly even when taps are off. Need someone to diagnose and fix ASAP.
              </p>
            </div>
          </Card>

          <Card>
            <div className="mb-2">
              <p className="text-[#6B7280] text-sm mb-1">Location</p>
              <p className="text-neutral-900">Toronto, ON</p>
              <p className="text-[#6B7280] text-sm">Search radius: 25 km</p>
            </div>
          </Card>

          <Card>
            <div className="mb-2">
              <p className="text-[#6B7280] text-sm mb-1">Timing</p>
              <p className="text-neutral-900">Within 48 hours</p>
            </div>
          </Card>

          <Card>
            <div className="mb-2">
              <p className="text-[#6B7280] text-sm mb-1">Budget</p>
              <p className="text-neutral-900">$100-150</p>
            </div>
          </Card>
        </div>

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
        <Button variant="primary" fullWidth onClick={onSubmit}>
          Send Request
        </Button>
      </div>
    </div>
  );
}
