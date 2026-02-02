import { useState } from "react";
import { Star, MapPin, SlidersHorizontal, List, Map } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Card } from "../components/patchwork/Card";
import { Badge } from "../components/patchwork/Badge";
import { Avatar } from "../components/patchwork/Avatar";

export function Browse({ onNavigate, onBack }: { onNavigate: (screen: string) => void; onBack: () => void }) {
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
    },
    {
      name: "Sarah Johnson",
      category: "Handyman",
      rating: 5.0,
      reviews: 45,
      price: "$65/hr",
      distance: "11.3 km",
      nextAvailable: "Thu, Nov 7",
      verified: true
    }
  ];

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      <AppBar 
        title="Plumbing" 
        onBack={onBack}
        action={
          <button className="p-2">
            <SlidersHorizontal size={20} className="text-neutral-900" />
          </button>
        }
      />

      <div className="px-4 py-4 bg-white border-b border-neutral-200">
        <div className="flex items-center justify-between mb-3">
          <p className="text-[#6B7280]">47 Taskers near you</p>
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

        <p className="text-[#6B7280] text-sm">
          Ranked by rating, proximity, and activity—never paid placement
        </p>
      </div>

      {view === "map" ? (
        <div className="h-[400px] bg-neutral-200 flex items-center justify-center">
          <p className="text-[#6B7280]">Map View</p>
        </div>
      ) : (
        <div className="p-4 space-y-3">
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
      )}

      <BottomNav active="browse" onNavigate={onNavigate} />
    </div>
  );
}
