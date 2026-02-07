import { Search, MapPin, PlusCircle, List, MessageCircle, Briefcase, Calendar, TrendingUp, Star, Eye, Heart } from "lucide-react";
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Card } from "../components/patchwork/Card";
import { Button } from "../components/patchwork/Button";
import { Badge } from "../components/patchwork/Badge";

export function HomeUnified({ onNavigate, hasTaskerProfile = false }: { onNavigate: (screen: string) => void; hasTaskerProfile?: boolean }) {
  const backendCategories = useQuery(api.categories.listCategories);
  const categories = (backendCategories ?? []).map(c => c.name).slice(0, 8);

  const recentActivity = [
    { type: "quote", name: "Alex Chen", service: "Plumbing", time: "2h ago" },
    { type: "message", name: "Maria Garcia", service: "Cleaning", time: "5h ago" }
  ];

  const jobRequests = [
    { title: "Kitchen sink leak repair", location: "3.2 km away", time: "2h ago", status: "new" },
    { title: "Bathroom faucet installation", location: "8.1 km away", time: "5h ago", status: "quoted" }
  ];

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      <div className="bg-white px-4 pt-12 pb-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-neutral-900 mb-1">Hey, Jenny</h1>
            <p className="text-[#6B7280]">What can we help you with?</p>
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

      <div className="px-4 py-6 space-y-8">
        {/* HIRE TODAY SECTION */}
        <div>
          <h2 className="text-neutral-900 mb-4">Hire today</h2>

          <div className="grid grid-cols-2 gap-3 mb-4">
            {categories.slice(0, 6).map((cat) => (
              <Card key={cat} onClick={() => onNavigate("browse")}>
                <div className="text-center">
                  <div className="size-12 rounded-lg bg-neutral-100 mx-auto mb-2 flex items-center justify-center">
                    🔧
                  </div>
                  <p className="text-neutral-900 text-sm">{cat}</p>
                </div>
              </Card>
            ))}
          </div>

          <button onClick={() => onNavigate("categories")} className="text-[#4F46E5] text-sm mb-4">
            See all categories
          </button>

          <div className="space-y-3">
            <Card onClick={() => onNavigate("create")}>
              <div className="flex items-center gap-3">
                <div className="size-10 rounded-lg bg-indigo-100 flex items-center justify-center">
                  <PlusCircle size={20} className="text-[#4F46E5]" />
                </div>
                <div>
                  <p className="text-neutral-900">Post a job</p>
                  <p className="text-[#6B7280] text-sm">Find providers for a task</p>
                </div>
              </div>
            </Card>

            <Card onClick={() => onNavigate("browse")}>
              <div className="flex items-center gap-3">
                <div className="size-10 rounded-lg bg-indigo-100 flex items-center justify-center">
                  <Heart size={20} className="text-[#4F46E5]" />
                </div>
                <div>
                  <p className="text-neutral-900">Saved Taskers</p>
                  <p className="text-[#6B7280] text-sm">3 saved</p>
                </div>
              </div>
            </Card>
          </div>

          {recentActivity.length > 0 && (
            <>
              <h3 className="text-neutral-900 mt-6 mb-3">Recent activity</h3>
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
            </>
          )}
        </div>

        {/* EARN TODAY SECTION */}
        <div>
          <h2 className="text-neutral-900 mb-4">Earn today</h2>

          {!hasTaskerProfile ? (
            <Card>
              <div className="text-center py-4">
                <div className="size-16 rounded-full bg-indigo-100 mx-auto mb-3 flex items-center justify-center">
                  <Briefcase size={24} className="text-[#4F46E5]" />
                </div>
                <p className="text-neutral-900 mb-2">Become a Tasker</p>
                <p className="text-[#6B7280] text-sm mb-4">
                  Offer your services and earn within 100 km
                </p>
                <Button variant="primary" onClick={() => onNavigate("tasker-onboarding1")}>
                  Get Started (2–3 min)
                </Button>
              </div>
            </Card>
          ) : (
            <>
              <div className="grid grid-cols-2 gap-3 mb-4">
                <Card>
                  <div className="flex items-center gap-2 mb-2">
                    <Eye size={16} className="text-[#6B7280]" />
                    <p className="text-[#6B7280] text-sm">Profile views</p>
                  </div>
                  <p className="text-2xl text-neutral-900">127</p>
                  <p className="text-[#16A34A] text-sm">+12%</p>
                </Card>

                <Card>
                  <div className="flex items-center gap-2 mb-2">
                    <Calendar size={16} className="text-[#6B7280]" />
                    <p className="text-[#6B7280] text-sm">Requests</p>
                  </div>
                  <p className="text-2xl text-neutral-900">8</p>
                  <p className="text-[#6B7280] text-sm">This week</p>
                </Card>

                <Card>
                  <div className="flex items-center gap-2 mb-2">
                    <TrendingUp size={16} className="text-[#6B7280]" />
                    <p className="text-[#6B7280] text-sm">Completion</p>
                  </div>
                  <p className="text-2xl text-neutral-900">98%</p>
                </Card>

                <Card>
                  <div className="flex items-center gap-2 mb-2">
                    <Star size={16} className="text-[#6B7280]" />
                    <p className="text-[#6B7280] text-sm">Avg rating</p>
                  </div>
                  <p className="text-2xl text-neutral-900">4.9</p>
                  <p className="text-[#16A34A] text-sm">+0.1</p>
                </Card>
              </div>

              <div className="space-y-3 mb-4">
                <Card onClick={() => onNavigate("create")}>
                  <div className="flex items-center gap-3">
                    <div className="size-10 rounded-lg bg-indigo-100 flex items-center justify-center">
                      <Briefcase size={20} className="text-[#4F46E5]" />
                    </div>
                    <div>
                      <p className="text-neutral-900">New Listing</p>
                      <p className="text-[#6B7280] text-sm">Update your services</p>
                    </div>
                  </div>
                </Card>

                <Card onClick={() => onNavigate("profile")}>
                  <div className="flex items-center gap-3">
                    <div className="size-10 rounded-lg bg-indigo-100 flex items-center justify-center">
                      <Calendar size={20} className="text-[#4F46E5]" />
                    </div>
                    <div>
                      <p className="text-neutral-900">Update Availability</p>
                      <p className="text-[#6B7280] text-sm">Manage your schedule</p>
                    </div>
                  </div>
                </Card>
              </div>

              <h3 className="text-neutral-900 mb-3">Incoming requests</h3>
              <div className="space-y-3">
                {jobRequests.map((job, i) => (
                  <Card key={i} onClick={() => onNavigate("job-detail")}>
                    <div className="flex items-start justify-between mb-2">
                      <div className="flex-1">
                        <div className="flex items-start gap-2 mb-1">
                          <p className="text-neutral-900 flex-1">{job.title}</p>
                          {job.status === "new" && <Badge variant="warning">New</Badge>}
                        </div>
                        <div className="flex items-center justify-between">
                          <span className="text-[#6B7280] text-sm">{job.location}</span>
                          <span className="text-[#6B7280] text-sm">{job.time}</span>
                        </div>
                      </div>
                    </div>
                  </Card>
                ))}
              </div>
            </>
          )}
        </div>
      </div>

      <BottomNav active="home" onNavigate={onNavigate} />
    </div>
  );
}
