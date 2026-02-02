import { Search, MapPin, PlusCircle, List, MessageCircle } from "lucide-react";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Card } from "../components/patchwork/Card";

export function Home({ onNavigate }: { onNavigate: (screen: string) => void }) {
  const categories = [
    "Plumbing", "Electrical", "Handyman", "Cleaning",
    "Moving", "Painting", "Gardening", "Pest Control",
    "Appliance Repair", "HVAC", "IT Support", "Tutoring"
  ];

  const recentActivity = [
    { type: "quote", name: "Alex Chen", service: "Plumbing", time: "2h ago" },
    { type: "message", name: "Maria Garcia", service: "Cleaning", time: "5h ago" },
    { type: "completed", name: "John Smith", service: "Electrical", time: "1d ago" }
  ];

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      <div className="bg-white px-4 pt-12 pb-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-neutral-900 mb-1">Hey, Jenny</h1>
            <p className="text-[#6B7280]">What do you need help with?</p>
          </div>
          <div className="size-12 rounded-lg bg-gradient-to-br from-[#4F46E5] to-[#7C3AED]" />
        </div>

        <div className="relative mb-4">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]" size={20} />
          <input
            type="text"
            placeholder="Search for services..."
            className="w-full pl-10 pr-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1"
            onClick={() => onNavigate("categories")}
          />
        </div>

        <button className="flex items-center gap-2 text-[#4F46E5]">
          <MapPin size={16} />
          <span>Toronto, ON • 25 km radius</span>
        </button>
      </div>

      <div className="px-4 py-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-neutral-900">Popular near you</h2>
          <button onClick={() => onNavigate("categories")} className="text-[#4F46E5]">
            See all 65+
          </button>
        </div>

        <div className="grid grid-cols-2 gap-3 mb-8">
          {categories.map((cat) => (
            <Card key={cat} onClick={() => onNavigate("browse")}>
              <div className="text-center">
                <div className="size-12 rounded-lg bg-neutral-100 mx-auto mb-2 flex items-center justify-center">
                  🔧
                </div>
                <p className="text-neutral-900">{cat}</p>
              </div>
            </Card>
          ))}
        </div>

        <h2 className="text-neutral-900 mb-4">Quick actions</h2>
        <div className="space-y-3 mb-8">
          <Card onClick={() => onNavigate("post-job")}>
            <div className="flex items-center gap-3">
              <div className="size-10 rounded-lg bg-indigo-100 flex items-center justify-center">
                <PlusCircle size={20} className="text-[#4F46E5]" />
              </div>
              <div>
                <p className="text-neutral-900">Post a job</p>
                <p className="text-[#6B7280] text-sm">Describe what you need</p>
              </div>
            </div>
          </Card>

          <Card onClick={() => onNavigate("browse")}>
            <div className="flex items-center gap-3">
              <div className="size-10 rounded-lg bg-indigo-100 flex items-center justify-center">
                <List size={20} className="text-[#4F46E5]" />
              </div>
              <div>
                <p className="text-neutral-900">Browse Taskers</p>
                <p className="text-[#6B7280] text-sm">Explore by category</p>
              </div>
            </div>
          </Card>

          <Card onClick={() => onNavigate("messages")}>
            <div className="flex items-center gap-3">
              <div className="size-10 rounded-lg bg-indigo-100 flex items-center justify-center">
                <MessageCircle size={20} className="text-[#4F46E5]" />
              </div>
              <div>
                <p className="text-neutral-900">View messages</p>
                <p className="text-[#6B7280] text-sm">2 unread</p>
              </div>
            </div>
          </Card>
        </div>

        <h2 className="text-neutral-900 mb-4">Recent activity</h2>
        <div className="space-y-3">
          {recentActivity.map((item, i) => (
            <Card key={i}>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="size-10 rounded-lg bg-neutral-200" />
                  <div>
                    <p className="text-neutral-900">{item.name}</p>
                    <p className="text-[#6B7280] text-sm">{item.service}</p>
                  </div>
                </div>
                <span className="text-[#6B7280] text-sm">{item.time}</span>
              </div>
            </Card>
          ))}
        </div>
      </div>

      <BottomNav active="home" onNavigate={onNavigate} />
    </div>
  );
}
