import { useState, useEffect } from "react";
import { Star, MapPin, SlidersHorizontal, List, Map, Loader2 } from "lucide-react";
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Id } from "../../convex/_generated/dataModel";
import { useUserLocation } from "../hooks/useUserLocation";
import { AppBar } from "../components/patchwork/AppBar";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Card } from "../components/patchwork/Card";
import { Avatar } from "../components/patchwork/Avatar";

interface BrowseProps {
  onNavigate: (screen: string) => void;
  onBack: () => void;
  onViewTasker?: (taskerId: Id<"taskerProfiles">) => void;
}

export function Browse({ onNavigate, onBack, onViewTasker }: BrowseProps) {
  const [view, setView] = useState<"list" | "map">("list");
  const { location, isLoading: isLocationLoading, requestLocation, error: locationError } = useUserLocation();

  useEffect(() => {
    if (!location && !isLocationLoading && !locationError) {
      requestLocation();
    }
  }, [location, isLocationLoading, requestLocation, locationError]);

  const providers = useQuery(
    api.search.searchTaskers,
    location ? {
      lat: location.lat,
      lng: location.lng,
      radiusKm: 25,
    } : "skip"
  );

  const isLoading = isLocationLoading || (location && providers === undefined);
  const showEmpty = !isLoading && providers && providers.length === 0;

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      <AppBar 
        title="Browse Taskers" 
        onBack={onBack}
        action={
          <button className="p-2">
            <SlidersHorizontal size={20} className="text-neutral-900" />
          </button>
        }
      />

      <div className="px-4 py-4 bg-white border-b border-neutral-200">
        <div className="flex items-center justify-between mb-3">
          <p className="text-[#6B7280]">
            {isLoading ? "Finding Taskers..." : `${providers?.length || 0} Taskers near you`}
          </p>
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

      {isLoading ? (
        <div className="flex flex-col items-center justify-center h-64 text-[#6B7280]">
          <Loader2 className="h-8 w-8 animate-spin mb-2" />
          <p>Loading nearby Taskers...</p>
        </div>
      ) : locationError ? (
        <div className="p-8 text-center text-[#6B7280]">
          <MapPin className="h-12 w-12 mx-auto mb-3 text-neutral-300" />
          <p className="mb-2">Location access required</p>
          <p className="text-sm mb-4">{locationError}</p>
          <button 
            onClick={() => requestLocation()}
            className="text-[#4F46E5] font-medium"
          >
            Try Again
          </button>
        </div>
      ) : showEmpty ? (
        <div className="p-8 text-center text-[#6B7280]">
          <p>No Taskers found in your area.</p>
          <p className="text-sm mt-2">Try increasing your search radius.</p>
        </div>
      ) : view === "map" ? (
        <div className="h-[400px] bg-neutral-200 flex items-center justify-center">
          <p className="text-[#6B7280]">Map View coming soon</p>
        </div>
      ) : (
        <div className="p-4 space-y-3">
          {providers?.map((provider) => (
            <Card key={provider.id} onClick={() => {
              if (onViewTasker) {
                onViewTasker(provider.id);
              } else {
                onNavigate("provider-detail");
              }
            }}>
              <div className="flex gap-3">
                <Avatar src={provider.avatarUrl ?? provider.categoryPhotoUrl ?? ""} alt={provider.name} size="lg" />
                
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
