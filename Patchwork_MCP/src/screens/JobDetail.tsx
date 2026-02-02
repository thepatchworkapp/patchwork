import { MapPin, Clock, DollarSign, MessageCircle, X, Check } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Avatar } from "../components/patchwork/Avatar";
import { Badge } from "../components/patchwork/Badge";
import { Card } from "../components/patchwork/Card";

export function JobDetail({ onBack }: { onBack: () => void }) {
  return (
    <div className="min-h-screen bg-neutral-50 pb-24">
      <AppBar title="Job Request" onBack={onBack} />

      <div className="px-4 py-6 space-y-6">
        <Card>
          <div className="flex items-start gap-3 mb-4">
            <Avatar src="" alt="Sarah M." size="md" />
            <div className="flex-1">
              <p className="text-neutral-900 mb-1">Sarah M.</p>
              <div className="flex items-center gap-2">
                <Badge variant="success">Verified</Badge>
                <span className="text-[#6B7280] text-sm">3 completed jobs</span>
              </div>
            </div>
            <Badge variant="warning">New</Badge>
          </div>
        </Card>

        <div>
          <h2 className="text-neutral-900 mb-3">Kitchen sink leak repair</h2>
          <p className="text-[#6B7280] mb-4">
            Kitchen sink is leaking under the counter. Water drips constantly even when taps are off. Need someone to diagnose and fix ASAP. I have a shutoff valve under the sink that I've turned off for now.
          </p>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <Card>
            <div className="flex items-start gap-2">
              <MapPin size={20} className="text-[#6B7280] flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-[#6B7280] text-sm mb-1">Location</p>
                <p className="text-neutral-900">3.2 km away</p>
                <p className="text-[#6B7280] text-sm">Toronto, ON</p>
              </div>
            </div>
          </Card>

          <Card>
            <div className="flex items-start gap-2">
              <Clock size={20} className="text-[#6B7280] flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-[#6B7280] text-sm mb-1">Timing</p>
                <p className="text-neutral-900">Within 48h</p>
                <p className="text-[#6B7280] text-sm">Flexible</p>
              </div>
            </div>
          </Card>

          <Card>
            <div className="flex items-start gap-2">
              <DollarSign size={20} className="text-[#6B7280] flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-[#6B7280] text-sm mb-1">Budget</p>
                <p className="text-neutral-900">$100-150</p>
                <p className="text-[#6B7280] text-sm">Estimate</p>
              </div>
            </div>
          </Card>

          <Card>
            <div className="flex items-start gap-2">
              <MessageCircle size={20} className="text-[#6B7280] flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-[#6B7280] text-sm mb-1">Posted</p>
                <p className="text-neutral-900">2 hours ago</p>
                <p className="text-[#6B7280] text-sm">3 quotes sent</p>
              </div>
            </div>
          </Card>
        </div>

        <div>
          <h3 className="text-neutral-900 mb-3">Photos</h3>
          <div className="grid grid-cols-3 gap-2">
            {[1, 2].map((i) => (
              <div key={i} className="aspect-square bg-neutral-200 rounded-lg" />
            ))}
          </div>
        </div>

        <div className="bg-indigo-50 rounded-lg p-4">
          <p className="text-[#4F46E5] mb-2">💡 Response tip</p>
          <p className="text-[#6B7280] text-sm">
            Responding within 1 hour increases your chances of being hired by 60%. Be specific about your availability and pricing.
          </p>
        </div>
      </div>

      <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-neutral-200 p-4">
        <div className="max-w-[390px] mx-auto flex gap-3">
          <Button variant="secondary">
            <X size={20} />
          </Button>
          <Button variant="secondary" fullWidth>
            <MessageCircle size={20} className="mr-2" />
            Message
          </Button>
          <Button variant="primary" fullWidth>
            <Check size={20} className="mr-2" />
            Send Quote
          </Button>
        </div>
      </div>
    </div>
  );
}
