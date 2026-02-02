import { useState, useEffect } from "react";
import { useQuery } from "convex/react";
import { Star, MapPin, X, Check, Info, ChevronDown, Loader2 } from "lucide-react";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Badge } from "../components/patchwork/Badge";
import { Button } from "../components/patchwork/Button";
import { useUserLocation } from "../hooks/useUserLocation";
import { api } from "../../convex/_generated/api";

import { Id } from "../../convex/_generated/dataModel";

interface HomeSwipeProps {
  onNavigate: (screen: string) => void;
  onViewTasker?: (taskerId: Id<"taskerProfiles">) => void;
}

type TaskerCard = {
  id: Id<"taskerProfiles">;
  name: string;
  category: string;
  rating: number;
  reviews: number;
  price: string;
  distance: string;
  verified: boolean;
  bio: string;
  completedJobs: number;
};

export function HomeSwipe({ onNavigate, onViewTasker }: HomeSwipeProps) {
  const [selectedCategory, setSelectedCategory] = useState("All categories");
  const [showCategories, setShowCategories] = useState(false);
  const [currentCardIndex, setCurrentCardIndex] = useState(0);
  const [radiusKm, setRadiusKm] = useState(25);
  const [showRadiusModal, setShowRadiusModal] = useState(false);

  const {
    location,
    isLoading: locationLoading,
    requestLocation,
    error: locationError,
  } = useUserLocation();

  useEffect(() => {
    if (!location && !locationLoading && !locationError) {
      requestLocation();
    }
  }, [location, locationLoading, locationError, requestLocation]);

  useEffect(() => {
    setCurrentCardIndex(0);
  }, [selectedCategory, radiusKm]);

  const taskers = useQuery(
    api.search.searchTaskers,
    location
      ? {
          categorySlug:
            selectedCategory === "All categories"
              ? undefined
              : selectedCategory.toLowerCase(),
          lat: location.lat,
          lng: location.lng,
          radiusKm: radiusKm,
        }
      : "skip"
  );

  const categories = [
    "All categories",
    "Plumbing",
    "Electrical",
    "Handyman",
    "Cleaning",
    "Moving",
    "Painting",
    "Gardening",
    "Pest Control",
    "Appliance Repair",
    "HVAC",
    "IT Support",
    "Tutoring"
  ];

  if (locationError) {
    return (
      <div className="min-h-screen bg-neutral-50 flex flex-col items-center justify-center px-6 text-center">
        <MapPin className="w-10 h-10 text-neutral-300 mb-4" />
        <p className="text-neutral-900 mb-2">Location access required</p>
        <p className="text-neutral-600 text-sm mb-4">{locationError}</p>
        <button
          onClick={() => requestLocation()}
          className="text-[#4F46E5] font-medium"
        >
          Try Again
        </button>
        <BottomNav active="home" onNavigate={onNavigate} />
      </div>
    );
  }

  if (locationLoading || (!location && !locationError) || taskers === undefined) {
    return (
      <div className="min-h-screen bg-neutral-50 flex flex-col items-center justify-center">
        <Loader2 className="w-8 h-8 text-[#4F46E5] animate-spin mb-4" />
        <p className="text-neutral-600">Finding taskers near you...</p>
        <BottomNav active="home" onNavigate={onNavigate} />
      </div>
    );
  }

  const taskerList: TaskerCard[] = taskers ?? [];

  if (taskerList.length === 0) {
    return (
      <div className="min-h-screen bg-neutral-50 pb-20">
        <div className="bg-white px-4 pt-12 pb-4 border-b border-neutral-200">
          <div className="flex items-center justify-between mb-4">
            <h1 className="text-neutral-900">Discover Taskers</h1>
            <div className="size-10 rounded-lg bg-gradient-to-br from-[#4F46E5] to-[#7C3AED]" />
          </div>
          
          <button 
            onClick={() => setShowRadiusModal(true)}
            className="flex items-center gap-2 text-[#4F46E5] mb-3"
          >
            <MapPin size={16} />
            <span>Toronto, ON • {radiusKm} km radius</span>
          </button>

          <button
            onClick={() => setShowCategories(!showCategories)}
            className="w-full flex items-center justify-between px-4 py-3 border border-neutral-300 rounded-lg bg-white"
          >
            <span className="text-neutral-900">{selectedCategory}</span>
            <ChevronDown size={20} className="text-neutral-600" />
          </button>

          {showCategories && (
            <div className="absolute left-4 right-4 bg-white border border-neutral-300 rounded-lg shadow-lg z-50 max-h-64 overflow-y-auto">
              {categories.map((cat) => (
                <button
                  key={cat}
                  onClick={() => {
                    setSelectedCategory(cat);
                    setShowCategories(false);
                  }}
                  className={`w-full text-left px-4 py-3 hover:bg-neutral-50 ${
                    cat === selectedCategory ? "bg-indigo-50 text-[#4F46E5]" : "text-neutral-900"
                  }`}
                >
                  {cat}
                </button>
              ))}
            </div>
          )}
        </div>

        <div className="flex items-center justify-center h-96">
          <div className="text-center px-8">
            <p className="text-neutral-900 mb-2">No taskers found</p>
            <p className="text-[#6B7280]">
              Try adjusting your filters or search radius
            </p>
          </div>
        </div>

        {showRadiusModal && (
          <div className="fixed inset-0 bg-black/50 z-50 flex items-end">
            <div className="bg-white rounded-t-3xl w-full max-w-[390px] mx-auto p-6 pb-8">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-neutral-900">Search Radius</h2>
                <button
                  onClick={() => setShowRadiusModal(false)}
                  className="text-[#6B7280]"
                >
                  <X size={24} />
                </button>
              </div>

              <div className="mb-6">
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-2 text-[#4F46E5]">
                    <MapPin size={16} />
                    <span>Toronto, ON</span>
                  </div>
                  <span className="text-neutral-900">{radiusKm} km</span>
                </div>

                <input
                  type="range"
                  min="1"
                  max="250"
                  value={radiusKm}
                  onChange={(e) => setRadiusKm(Number(e.target.value))}
                  className="w-full h-2 bg-neutral-200 rounded-lg appearance-none cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-6 [&::-webkit-slider-thumb]:h-6 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-[#4F46E5] [&::-webkit-slider-thumb]:cursor-pointer [&::-moz-range-thumb]:w-6 [&::-moz-range-thumb]:h-6 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:bg-[#4F46E5] [&::-moz-range-thumb]:border-0 [&::-moz-range-thumb]:cursor-pointer"
                />

                <div className="flex items-center justify-between mt-2 text-sm text-[#6B7280]">
                  <span>1 km</span>
                  <span>250 km</span>
                </div>
              </div>

              <Button
                variant="primary"
                fullWidth
                onClick={() => setShowRadiusModal(false)}
              >
                Apply
              </Button>
            </div>
          </div>
        )}

        <BottomNav active="home" onNavigate={onNavigate} />
      </div>
    );
  }

  const currentTasker = taskerList[currentCardIndex];

  const handleSkip = () => {
    if (currentCardIndex < taskerList.length - 1) {
      setCurrentCardIndex(currentCardIndex + 1);
    } else {
      // Reset to beginning or show "no more taskers" message
      setCurrentCardIndex(0);
    }
  };

  const handleLike = () => {
    // Save tasker to favorites
    if (currentCardIndex < taskerList.length - 1) {
      setCurrentCardIndex(currentCardIndex + 1);
    } else {
      setCurrentCardIndex(0);
    }
  };

  const handleViewProfile = () => {
    if (onViewTasker && currentTasker) {
      onViewTasker(currentTasker.id);
    } else {
      onNavigate("provider-detail");
    }
  };

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      {/* Header */}
      <div className="bg-white px-4 pt-12 pb-4 border-b border-neutral-200">
        <div className="flex items-center justify-between mb-4">
          <h1 className="text-neutral-900">Discover Taskers</h1>
          <div className="size-10 rounded-lg bg-gradient-to-br from-[#4F46E5] to-[#7C3AED]" />
        </div>

        {/* Location - moved above category filter */}
        <button 
          onClick={() => setShowRadiusModal(true)}
          className="flex items-center gap-2 text-[#4F46E5] mb-3"
        >
          <MapPin size={16} />
          <span>Toronto, ON • {radiusKm} km radius</span>
        </button>

        {/* Category Filter */}
        <button
          onClick={() => setShowCategories(!showCategories)}
          className="w-full flex items-center justify-between px-4 py-3 border border-neutral-300 rounded-lg bg-white"
        >
          <span className="text-neutral-900">{selectedCategory}</span>
          <ChevronDown size={20} className="text-neutral-600" />
        </button>

        {showCategories && (
          <div className="absolute left-4 right-4 bg-white border border-neutral-300 rounded-lg shadow-lg z-50 max-h-64 overflow-y-auto">
            {categories.map((cat) => (
              <button
                key={cat}
                onClick={() => {
                  setSelectedCategory(cat);
                  setShowCategories(false);
                }}
                className={`w-full text-left px-4 py-3 hover:bg-neutral-50 ${
                  cat === selectedCategory ? "bg-indigo-50 text-[#4F46E5]" : "text-neutral-900"
                }`}
              >
                {cat}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Swipe Card */}
      {currentTasker ? (
        <div className="px-4 pt-6">
          <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
            {/* Profile Image Placeholder */}
            <div className="h-64 bg-gradient-to-br from-[#4F46E5] to-[#7C3AED] relative">
              <div className="absolute top-4 right-4">
                {currentTasker.verified && (
                  <Badge variant="success">Verified</Badge>
                )}
              </div>
            </div>

            {/* Tasker Info */}
            <div className="p-6">
              <div className="flex items-start justify-between mb-3">
                <div>
                  <h2 className="text-neutral-900 mb-1">{currentTasker.name}</h2>
                  <p className="text-[#6B7280]">{currentTasker.category}</p>
                </div>
                <div className="text-right">
                  <div className="flex items-center gap-1 mb-1">
                    <Star size={16} className="text-yellow-500 fill-yellow-500" />
                    <span className="text-neutral-900">{currentTasker.rating}</span>
                    <span className="text-[#6B7280]">({currentTasker.reviews})</span>
                  </div>
                  <p className="text-[#4F46E5]">{currentTasker.price}</p>
                </div>
              </div>

              <div className="flex items-center gap-4 mb-4 text-sm text-[#6B7280]">
                <div className="flex items-center gap-1">
                  <MapPin size={14} />
                  <span>{currentTasker.distance} away</span>
                </div>
                <div>
                  {currentTasker.completedJobs} jobs completed
                </div>
              </div>

              <p className="text-neutral-700 mb-4">
                {currentTasker.bio}
              </p>

              <button
                onClick={handleViewProfile}
                className="flex items-center gap-2 text-[#4F46E5] mb-6"
              >
                <Info size={16} />
                <span>View full profile</span>
              </button>

              {/* Action Buttons */}
              <div className="flex items-center gap-4">
                <button
                  onClick={handleSkip}
                  className="flex-1 h-14 rounded-full border-2 border-neutral-300 flex items-center justify-center active:bg-neutral-50"
                >
                  <X size={28} className="text-neutral-600" />
                </button>
                <button
                  onClick={handleLike}
                  className="flex-1 h-14 rounded-full bg-[#4F46E5] flex items-center justify-center active:bg-[#4338CA]"
                >
                  <Check size={28} className="text-white" />
                </button>
              </div>
            </div>
          </div>

          {/* Card Counter */}
          <div className="text-center mt-4 text-[#6B7280]">
             {currentCardIndex + 1} of {taskerList.length}
          </div>
        </div>
      ) : (
        <div className="flex items-center justify-center h-96">
          <div className="text-center px-8">
            <p className="text-neutral-900 mb-2">No more Taskers</p>
            <p className="text-[#6B7280] mb-6">
              Try adjusting your filters or check back later
            </p>
            <Button variant="primary" onClick={() => setCurrentCardIndex(0)}>
              Start Over
            </Button>
          </div>
        </div>
      )}

      {/* Radius Modal */}
      {showRadiusModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-end">
          <div className="bg-white rounded-t-3xl w-full max-w-[390px] mx-auto p-6 pb-8">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-neutral-900">Search Radius</h2>
              <button
                onClick={() => setShowRadiusModal(false)}
                className="text-[#6B7280]"
              >
                <X size={24} />
              </button>
            </div>

            <div className="mb-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2 text-[#4F46E5]">
                  <MapPin size={16} />
                  <span>Toronto, ON</span>
                </div>
                <span className="text-neutral-900">{radiusKm} km</span>
              </div>

              <input
                type="range"
                min="1"
                max="250"
                value={radiusKm}
                onChange={(e) => setRadiusKm(Number(e.target.value))}
                className="w-full h-2 bg-neutral-200 rounded-lg appearance-none cursor-pointer [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-6 [&::-webkit-slider-thumb]:h-6 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-[#4F46E5] [&::-webkit-slider-thumb]:cursor-pointer [&::-moz-range-thumb]:w-6 [&::-moz-range-thumb]:h-6 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:bg-[#4F46E5] [&::-moz-range-thumb]:border-0 [&::-moz-range-thumb]:cursor-pointer"
              />

              <div className="flex items-center justify-between mt-2 text-sm text-[#6B7280]">
                <span>1 km</span>
                <span>250 km</span>
              </div>
            </div>

            <Button
              variant="primary"
              fullWidth
              onClick={() => setShowRadiusModal(false)}
            >
              Apply
            </Button>
          </div>
        </div>
      )}

      <BottomNav active="home" onNavigate={onNavigate} />
    </div>
  );
}
