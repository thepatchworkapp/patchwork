import { Star, Heart, MessageCircle, Loader2 } from "lucide-react";
import { useState } from "react";
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Id } from "../../convex/_generated/dataModel";
import { AppBar } from "../components/patchwork/AppBar";
import { Avatar } from "../components/patchwork/Avatar";
import { Badge } from "../components/patchwork/Badge";
import { Button } from "../components/patchwork/Button";
import { Chip } from "../components/patchwork/Chip";
import { Card } from "../components/patchwork/Card";

interface ProviderDetailProps {
  taskerId: Id<"taskerProfiles"> | null;
  onBack: () => void;
  onNavigate: (screen: string) => void;
}

export function ProviderDetail({ taskerId, onBack, onNavigate }: ProviderDetailProps) {
  const [selectedCategoryIndex, setSelectedCategoryIndex] = useState(0);
  
  const tasker = useQuery(
    api.taskers.getTaskerById,
    taskerId ? { taskerId } : "skip"
  );

  if (!taskerId) {
    return (
      <div className="min-h-screen bg-neutral-50 flex items-center justify-center">
        <p className="text-neutral-600">No tasker selected</p>
      </div>
    );
  }

  if (tasker === undefined) {
    return (
      <div className="min-h-screen bg-neutral-50 flex flex-col items-center justify-center">
        <Loader2 className="w-8 h-8 text-[#4F46E5] animate-spin mb-4" />
        <p className="text-neutral-600">Loading profile...</p>
      </div>
    );
  }

  if (tasker === null) {
    return (
      <div className="min-h-screen bg-neutral-50 pb-24">
        <AppBar onBack={onBack} />
        <div className="flex items-center justify-center h-64">
          <p className="text-neutral-600">Tasker not found</p>
        </div>
      </div>
    );
  }

  const selectedCategory = tasker.categories[selectedCategoryIndex];
  const formatPrice = () => {
    if (!selectedCategory) return "Contact for pricing";
    if (selectedCategory.rateType === "hourly" && selectedCategory.hourlyRate) {
      return `$${(selectedCategory.hourlyRate / 100).toFixed(0)}/hr`;
    }
    if (selectedCategory.rateType === "fixed" && selectedCategory.fixedRate) {
      return `$${(selectedCategory.fixedRate / 100).toFixed(0)} flat`;
    }
    return "Contact for pricing";
  };

  const formatDate = (timestamp: number) => {
    return new Date(timestamp).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

  return (
    <div className="min-h-screen bg-neutral-50 pb-24">
      <AppBar onBack={onBack} />

      <div className="bg-white px-4 pt-4 pb-6">
        <div className="flex items-start gap-4 mb-4">
          <Avatar src="" alt={tasker.displayName} size="lg" />
          <div className="flex-1">
            <h1 className="text-neutral-900 mb-2">{tasker.displayName}</h1>
            <p className="text-[#6B7280] mb-2">
              {selectedCategory?.categoryName || "Service Provider"}
            </p>
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-1">
                <Star size={16} className="fill-yellow-400 text-yellow-400" />
                <span>{tasker.rating.toFixed(1)}</span>
                <span className="text-[#6B7280]">({tasker.reviewCount})</span>
              </div>
              {tasker.verified && (
                <Badge variant="success">Verified</Badge>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="px-4 py-6 space-y-6">
        {tasker.categories.length > 1 && (
          <div>
            <h2 className="text-neutral-900 mb-3">Services</h2>
            <div className="flex flex-wrap gap-2">
              {tasker.categories.map((cat, index) => (
                <Chip
                  key={cat.id}
                  label={cat.categoryName}
                  active={selectedCategoryIndex === index}
                  onClick={() => setSelectedCategoryIndex(index)}
                />
              ))}
            </div>
          </div>
        )}

        <div>
          <h2 className="text-neutral-900 mb-3">About</h2>
          <p className="text-[#6B7280]">
            {selectedCategory?.bio || tasker.bio || "No bio provided."}
          </p>
        </div>

        <div>
          <h2 className="text-neutral-900 mb-3">Pricing</h2>
          <Card>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-[#6B7280]">
                  {selectedCategory?.rateType === "hourly" ? "Hourly rate" : "Fixed rate"}
                </span>
                <span className="text-neutral-900">{formatPrice()}</span>
              </div>
              {selectedCategory && (
                <div className="flex justify-between">
                  <span className="text-[#6B7280]">Service area</span>
                  <span className="text-neutral-900">{selectedCategory.serviceRadius} km radius</span>
                </div>
              )}
              <div className="flex justify-between">
                <span className="text-[#6B7280]">Jobs completed</span>
                <span className="text-neutral-900">{tasker.completedJobs}</span>
              </div>
            </div>
          </Card>
        </div>

        <div>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-neutral-900">Reviews</h2>
            {tasker.reviewCount > 0 && (
              <button className="text-[#4F46E5]">See all {tasker.reviewCount}</button>
            )}
          </div>

          {tasker.reviews.length > 0 ? (
            <div className="space-y-3">
              {tasker.reviews.map((review) => (
                <Card key={review.id}>
                  <div className="flex items-start gap-3 mb-2">
                    <Avatar src="" alt={review.reviewerName} size="sm" />
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1">
                        <p className="text-neutral-900">{review.reviewerName}</p>
                        <Badge variant="success">Verified hire</Badge>
                      </div>
                      <div className="flex items-center gap-2 mb-2">
                        <div className="flex">
                          {Array.from({ length: review.rating }).map((_, i) => (
                            <Star key={i} size={14} className="fill-yellow-400 text-yellow-400" />
                          ))}
                        </div>
                        <span className="text-[#6B7280] text-sm">{formatDate(review.createdAt)}</span>
                      </div>
                      <p className="text-[#6B7280]">{review.text}</p>
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          ) : (
            <div className="bg-white rounded-lg p-4 text-center">
              <p className="text-[#6B7280]">No reviews yet</p>
            </div>
          )}
        </div>
      </div>

      <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-neutral-200 p-4">
        <div className="max-w-[390px] mx-auto flex gap-3">
          <button className="size-12 border border-neutral-300 rounded-lg flex items-center justify-center">
            <Heart size={20} className="text-neutral-900" />
          </button>
          <Button variant="primary" fullWidth onClick={() => onNavigate("chat")}>
            <div className="flex items-center justify-center gap-2">
              <MessageCircle size={20} />
              <span>Chat</span>
            </div>
          </Button>
        </div>
      </div>
    </div>
  );
}
