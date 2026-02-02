import { useState } from "react";
import { Star, MapPin, SlidersHorizontal, List, Map, Search, Clock, DollarSign } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Card } from "../components/patchwork/Card";
import { Badge } from "../components/patchwork/Badge";
import { Avatar } from "../components/patchwork/Avatar";
import { Button } from "../components/patchwork/Button";

export function BrowseUnified({ onNavigate, onBack, hasTaskerProfile = false }: { 
  onNavigate: (screen: string) => void; 
  onBack?: () => void;
  hasTaskerProfile?: boolean;
}) {
  const [activeTab, setActiveTab] = useState<"providers" | "jobs">("providers");
  const [view, setView] = useState<"list" | "map">("list");

  const providers = [
    {
      name: "Alex Chen",
      category: "Plumbing",
      rating: 4.9,
      reviews: 127,
      price: "$85/hr",
      distance: "3.2 km",
      nextAvailable: "Today",
      verified: true
    },
    {
      name: "Maria Garcia",
      category: "Cleaning",
      rating: 4.8,
      reviews: 203,
      price: "$45/hr",
      distance: "5.7 km",
      nextAvailable: "Tomorrow",
      verified: true
    },
    {
      name: "David Kim",
      category: "Electrical",
      rating: 4.7,
      reviews: 89,
      price: "$95/hr",
      distance: "8.1 km",
      nextAvailable: "Wed, Nov 6",
      verified: false
    }
  ];

  const jobs = [
    {
      title: "Kitchen sink leak repair",
      category: "Plumbing",
      distance: "3.2 km",
      time: "Within 48h",
      budget: "$100-150",
      posted: "2h ago"
    },
    {
      title: "Bathroom faucet installation",
      category: "Plumbing",
      distance: "8.1 km",
      time: "Flexible",
      budget: "Negotiable",
      posted: "5h ago"
    },
    {
      title: "Deep clean 3-bedroom apartment",
      category: "Cleaning",
      distance: "5.4 km",
      time: "This week",
      budget: "$200-250",
      posted: "1d ago"
    }
  ];

  const handleQuote = () => {
    if (!hasTaskerProfile) {
      // Show gated modal
      onNavigate("tasker-profile-gate");
    } else {
      onNavigate("job-detail");
    }
  };

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      {onBack ? (
        <AppBar 
          title="Browse" 
          onBack={onBack}
          action={
            <button className="p-2">
              <SlidersHorizontal size={20} className="text-neutral-900" />
            </button>
          }
        />
      ) : (
        <div className="bg-white px-4 pt-12 pb-4 border-b border-neutral-200">
          <h1 className="text-neutral-900 mb-4">Browse</h1>
        </div>
      )}

      <div className="bg-white px-4 py-4 border-b border-neutral-200">
        <div className="relative mb-4">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]" size={20} />
          <input
            type="text"
            placeholder={activeTab === "providers" ? "Search providers..." : "Search jobs..."}
            className="w-full pl-10 pr-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1"
          />
        </div>

        <div className="flex items-center justify-between mb-4">
          <button className="flex items-center gap-2 text-[#4F46E5] text-sm">
            <MapPin size={16} />
            <span>Within 100 km</span>
          </button>

          <div className="flex gap-1 bg-neutral-100 rounded-lg p-1">
            <button
              onClick={() => setView("list")}
              className={`p-2 rounded ${view === "list" ? "bg-white shadow-sm" : ""}`}
            >
              <List size={18} className={view === "list" ? "text-[#4F46E5]" : "text-[#6B7280]"} />
            </button>
            <button
              onClick={() => setView("map")}
              className={`p-2 rounded ${view === "map" ? "bg-white shadow-sm" : ""}`}
            >
              <Map size={18} className={view === "map" ? "text-[#4F46E5]" : "text-[#6B7280]"} />
            </button>
          </div>
        </div>

        <div className="flex gap-2 border-b border-neutral-200 -mb-4">
          <button
            onClick={() => setActiveTab("providers")}
            className={`px-4 py-3 relative ${
              activeTab === "providers" ? "text-[#4F46E5]" : "text-[#6B7280]"
            }`}
          >
            Providers
            {activeTab === "providers" && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#4F46E5]" />
            )}
          </button>
          <button
            onClick={() => setActiveTab("jobs")}
            className={`px-4 py-3 relative ${
              activeTab === "jobs" ? "text-[#4F46E5]" : "text-[#6B7280]"
            }`}
          >
            Jobs
            {activeTab === "jobs" && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#4F46E5]" />
            )}
          </button>
        </div>
      </div>

      {view === "map" ? (
        <div className="h-[400px] bg-neutral-200 flex items-center justify-center">
          <p className="text-[#6B7280]">Map View</p>
        </div>
      ) : (
        <>
          {activeTab === "providers" ? (
            <div className="p-4">
              <p className="text-[#6B7280] text-sm mb-3">
                Sorted by rating + proximity. No paid placements.
              </p>
              <div className="space-y-3">
                {providers.map((provider, i) => (
                  <Card key={i} onClick={() => onNavigate("provider-detail")}>
                    <div className="flex gap-3">
                      <Avatar src="" alt={provider.name} size="lg" />
                      
                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between mb-1">
                          <div>
                            <div className="flex items-center gap-2">
                              <p className="text-neutral-900">{provider.name}</p>
                              {provider.verified && (
                                <span className="text-[#16A34A]">✓</span>
                              )}
                            </div>
                            <p className="text-[#6B7280] text-sm">{provider.category}</p>
                          </div>
                        </div>

                        <div className="flex items-center gap-3 mb-2">
                          <div className="flex items-center gap-1">
                            <Star size={14} className="fill-yellow-400 text-yellow-400" />
                            <span className="text-sm">{provider.rating}</span>
                            <span className="text-[#6B7280] text-sm">({provider.reviews})</span>
                          </div>
                          <div className="flex items-center gap-1 text-[#6B7280] text-sm">
                            <MapPin size={14} />
                            <span>{provider.distance}</span>
                          </div>
                        </div>

                        <div className="flex items-center justify-between">
                          <p className="text-neutral-900">{provider.price}</p>
                          <Badge variant="success">{provider.nextAvailable}</Badge>
                        </div>
                      </div>
                    </div>
                  </Card>
                ))}
              </div>
            </div>
          ) : (
            <div className="p-4">
              <p className="text-[#6B7280] text-sm mb-3">
                Open requests within 100 km. Respond quickly to increase your chances.
              </p>
              <div className="space-y-3">
                {jobs.map((job, i) => (
                  <Card key={i}>
                    <div className="mb-3">
                      <div className="flex items-start justify-between mb-2">
                        <div className="flex-1">
                          <p className="text-neutral-900 mb-1">{job.title}</p>
                          <p className="text-[#6B7280] text-sm">{job.category}</p>
                        </div>
                        <Badge variant="warning">New</Badge>
                      </div>

                      <div className="grid grid-cols-2 gap-2 text-sm mb-3">
                        <div className="flex items-center gap-2 text-[#6B7280]">
                          <MapPin size={14} />
                          <span>{job.distance}</span>
                        </div>
                        <div className="flex items-center gap-2 text-[#6B7280]">
                          <Clock size={14} />
                          <span>{job.time}</span>
                        </div>
                        <div className="flex items-center gap-2 text-[#6B7280]">
                          <DollarSign size={14} />
                          <span>{job.budget}</span>
                        </div>
                        <div className="text-[#6B7280]">
                          {job.posted}
                        </div>
                      </div>
                    </div>

                    <div className="flex gap-2">
                      <Button variant="secondary" onClick={() => onNavigate("job-detail")}>
                        View
                      </Button>
                      <Button variant="primary" fullWidth onClick={handleQuote}>
                        Send Quote
                      </Button>
                    </div>
                  </Card>
                ))}
              </div>
            </div>
          )}
        </>
      )}

      <BottomNav active="browse" onNavigate={onNavigate} />
    </div>
  );
}
