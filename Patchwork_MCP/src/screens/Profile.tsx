import { ChevronRight, HelpCircle, LogOut, MapPin, Star, Lock, Moon } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Avatar } from "../components/patchwork/Avatar";
import { Button } from "../components/patchwork/Button";
import { Badge } from "../components/patchwork/Badge";
import { Card } from "../components/patchwork/Card";
import { Chip } from "../components/patchwork/Chip";
import { useState, useEffect } from "react";
import { useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { signOut } from "../lib/auth";

export function Profile({ 
  onNavigate, 
  onSwitchToTasker, 
  userPhoto, 
  pendingNewCategory = null,
  onCategoryModalClosed = () => {},
  subscriptionPlan = "none"
}: { 
  onNavigate: (screen: string) => void; 
  onSwitchToTasker: () => void;
  userPhoto?: string; 
  pendingNewCategory?: string | null;
  onCategoryModalClosed?: () => void;
  subscriptionPlan?: "none" | "tasker" | "basic" | "premium";
}) {
  const [showCategoryModal, setShowCategoryModal] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  // Auto-open modal for pending new category
  useEffect(() => {
    if (pendingNewCategory) {
      handleCategoryClick(pendingNewCategory);
    }
  }, [pendingNewCategory]);

  // Initialize rate based on type when modal opens
  const handleCategoryClick = (category: string) => {
    setSelectedCategory(category);
    setShowCategoryModal(true);
  };

  const handleCloseModal = () => {
    setShowCategoryModal(false);
    onCategoryModalClosed();
  };

  // Fetch real user data from Convex
  const userData = useQuery(api.users.getCurrentUser);
  const taskerProfile = useQuery(api.taskers.getTaskerProfile);
  const jobs = useQuery(api.jobs.listJobs, { limit: 100 });
  const setGhostMode = useMutation(api.taskers.setGhostMode);
  const cancelSubscription = useMutation(api.taskers.cancelSubscription);
  const [isCancellingSubscription, setIsCancellingSubscription] = useState(false);

  // Show loading state while data is being fetched
  if (userData === undefined || taskerProfile === undefined) {
    return (
      <div className="min-h-screen bg-neutral-50 flex items-center justify-center">
        <div className="text-center">
          <div className="inline-block size-8 border-4 border-[#4F46E5] border-t-transparent rounded-full animate-spin mb-3"></div>
          <p className="text-[#6B7280]">Loading profile...</p>
        </div>
      </div>
    );
  }

  // If no user data, show error state
  if (!userData) {
    return (
      <div className="min-h-screen bg-neutral-50 flex items-center justify-center">
        <div className="text-center px-4">
          <p className="text-neutral-900 mb-2">Unable to load profile</p>
          <p className="text-[#6B7280] text-sm">Please try again later</p>
        </div>
      </div>
    );
  }

  // Format member since date
  const memberSince = new Date(userData.createdAt).toLocaleDateString('en-US', { 
    month: 'long', 
    year: 'numeric' 
  });

  const profileCategories = taskerProfile?.categories ?? [];
  const selectedCategoryDetails =
    selectedCategory === null
      ? null
      : profileCategories.find((category) => category.categoryName === selectedCategory) ?? null;
  const selectedCategoryRateLabel =
    !selectedCategoryDetails
      ? null
      : selectedCategoryDetails.rateType === "hourly"
        ? selectedCategoryDetails.hourlyRate
          ? `$${(selectedCategoryDetails.hourlyRate / 100).toFixed(0)}/hr`
          : "Rate on request"
        : selectedCategoryDetails.fixedRate
          ? `$${(selectedCategoryDetails.fixedRate / 100).toFixed(0)}`
          : "Rate on request";
  const taskerSubscriptionPlan = taskerProfile?.subscriptionPlan ?? subscriptionPlan;
  const hasActiveSubscription =
    taskerProfile?.hasActiveSubscription ?? taskerSubscriptionPlan !== "none";
  const subscriptionStatus =
    taskerProfile?.subscriptionStatus ?? (hasActiveSubscription ? "active" : "inactive");
  const isCancellationScheduled = subscriptionStatus === "cancel_at_period_end";
  const isGhostMode = taskerProfile?.ghostMode ?? false;
  const subscriptionAccessType = taskerProfile?.subscriptionAccessType;
  const subscriptionPlanLabel =
    taskerSubscriptionPlan === "tasker"
      ? subscriptionAccessType === "lifetime"
        ? "Lifetime access"
        : subscriptionAccessType === "weekly"
          ? "Weekly access"
          : "Tasker access"
      : taskerSubscriptionPlan === "premium"
        ? "Premium plan"
        : taskerSubscriptionPlan === "basic"
          ? "Basic plan"
          : "No active plan";
  const subscriptionEndsAtLabel = taskerProfile?.subscriptionEndsAt
    ? new Date(taskerProfile.subscriptionEndsAt).toLocaleDateString("en-US", {
        month: "long",
        day: "numeric",
        year: "numeric",
      })
    : null;
  const seekerJobs = (jobs ?? []).filter((job) => job.seekerId === userData._id);

  // Build user object from real data
  const user = {
    name: userData.name,
    photo: userPhoto || userData.photo || "",
    memberSince,
    location: {
      city: userData.location.city,
      province: userData.location.province
    },
    roles: {
      isSeeker: userData.roles.isSeeker,
      isTasker: userData.roles.isTasker
    },
    taskerInfo: taskerProfile ? {
      displayName: taskerProfile.displayName,
      categories: profileCategories.map((category) => category.categoryName),
      rating: taskerProfile.rating,
      reviewCount: taskerProfile.reviewCount,
      completedJobs: taskerProfile.completedJobs,
      responseTime: taskerProfile.responseTime || "N/A",
      serviceRadius: profileCategories[0]?.serviceRadius || 0,
      verified: taskerProfile.verified,
      hourlyRate: profileCategories[0]?.hourlyRate 
        ? `$${(profileCategories[0].hourlyRate / 100).toFixed(0)}/hr`
        : "N/A"
    } : {
      displayName: "",
      categories: [],
      rating: 0,
      reviewCount: 0,
      completedJobs: 0,
      responseTime: "N/A",
      serviceRadius: 0,
      verified: false,
      hourlyRate: "N/A"
    },
    seekerInfo: {
      jobsPosted: seekerJobs.length,
      completedJobs: seekerJobs.filter((job) => job.status === "completed").length,
      rating: 0
    }
  };

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      <AppBar title="Profile" />

      {/* Profile Header */}
      <div className="bg-white px-4 py-6 mb-4">
        <div className="flex items-start gap-4 mb-4">
          <div className="relative">
            <Avatar src={user.photo} alt={user.name} size="lg" />
            {user.roles.isTasker && isGhostMode && (
              <div className="absolute bottom-0 right-0 size-6 rounded-full bg-[#6B7280] flex items-center justify-center shadow-lg">
                <Moon size={14} className="text-white" />
              </div>
            )}
          </div>
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-1">
              <h2 className="text-neutral-900">{user.name}</h2>
              {user.roles.isTasker && user.taskerInfo.verified && (
                <span className="text-[#16A34A]">✓</span>
              )}
            </div>
            <div className="flex flex-wrap gap-2">
              {user.roles.isSeeker && (
                <Badge variant="neutral">Seeker</Badge>
              )}
              {user.roles.isTasker && (
                <Badge variant="primary">Tasker</Badge>
              )}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2 text-[#6B7280] text-sm mb-4">
          <MapPin size={16} />
          <span>{user.location.city}, {user.location.province}</span>
        </div>

        <div className="flex items-center gap-4 text-sm mb-4">
          <div>
            <span className="text-[#6B7280]">Member since</span>
            <p className="text-neutral-900">{user.memberSince}</p>
          </div>
        </div>

        {user.roles.isTasker && (
          <div className="rounded-2xl border border-neutral-200 p-4">
            <div className="flex items-start justify-between gap-3 mb-3">
              <div>
                <p className="text-neutral-900">{subscriptionPlanLabel}</p>
                <p className="text-[#6B7280] text-sm">
                  {!hasActiveSubscription
                    ? "Ghost Mode is locked on until you activate a paid plan."
                    : isCancellationScheduled && subscriptionEndsAtLabel
                      ? `Cancellation is scheduled for ${subscriptionEndsAtLabel}. Ghost Mode turns back on automatically then.`
                      : "Your profile is discoverable and Ghost Mode can be toggled at any time."}
                </p>
              </div>
              <Badge variant={!hasActiveSubscription ? "neutral" : "primary"}>
                {!hasActiveSubscription
                  ? "Ghost Mode on"
                  : isCancellationScheduled
                    ? "Ending soon"
                    : "Active"}
              </Badge>
            </div>

            {!hasActiveSubscription ? (
              <Button
                variant="primary"
                fullWidth
                onClick={() => onNavigate("subscriptions")}
              >
                Activate a subscription
              </Button>
            ) : (
              <div className="flex gap-3">
                <Button
                  variant="secondary"
                  fullWidth
                  onClick={() => onNavigate("subscriptions")}
                >
                  Manage access
                </Button>
                {subscriptionAccessType !== "lifetime" && (
                  <Button
                    variant="secondary"
                    fullWidth
                    disabled={isCancellationScheduled || isCancellingSubscription}
                    onClick={async () => {
                      if (isCancellationScheduled) {
                        return;
                      }

                      const confirmed = window.confirm(
                        "Cancel your subscription at the end of the current term?",
                      );
                      if (!confirmed) {
                        return;
                      }

                      setIsCancellingSubscription(true);
                      try {
                        await cancelSubscription({});
                      } finally {
                        setIsCancellingSubscription(false);
                      }
                    }}
                  >
                    {isCancellationScheduled
                      ? "Cancellation scheduled"
                      : isCancellingSubscription
                        ? "Cancelling..."
                        : "Cancel subscription"}
                  </Button>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Tasker Profile Section */}
      <div className="bg-white px-4 py-6 mb-4 relative">
        {!user.roles.isTasker && (
          <>
            {/* Overlay for locked state */}
            <div className="absolute inset-0 bg-white/80 backdrop-blur-[2px] z-10 rounded-lg flex items-center justify-center">
              <div className="text-center px-4">
                <div className="inline-flex items-center justify-center size-12 rounded-full bg-neutral-100 mb-3">
                  <Lock size={24} className="text-[#6B7280]" />
                </div>
                <Button variant="primary" onClick={onSwitchToTasker}>
                  Sign up as a Tasker
                </Button>
              </div>
            </div>
          </>
        )}

        <div className={!user.roles.isTasker ? "opacity-30" : ""}>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-neutral-900">Tasker Profile</h3>
          </div>

          {user.taskerInfo.displayName !== user.name && (
            <p className="text-[#6B7280] mb-4">
              Listed as: <span className="text-neutral-900">{user.taskerInfo.displayName}</span>
            </p>
          )}

          <div className="grid grid-cols-2 gap-3 mb-4">
            <Card>
              <div className="flex items-center gap-2 mb-1">
                <Star size={16} className="fill-yellow-400 text-yellow-400" />
                <span className="text-2xl text-neutral-900">{user.taskerInfo.rating}</span>
              </div>
              <p className="text-[#6B7280] text-sm">{user.taskerInfo.reviewCount} reviews</p>
            </Card>

            <Card>
              <p className="text-2xl text-neutral-900 mb-1">{user.taskerInfo.completedJobs}</p>
              <p className="text-[#6B7280] text-sm">Jobs completed</p>
            </Card>
          </div>

          <div className="mb-4">
            <div className="flex items-center justify-between mb-3">
              <p className="text-neutral-900">Service Categories</p>
            </div>
            <div className="flex flex-wrap gap-2">
              {user.taskerInfo.categories.map((category) => (
                <Chip
                  key={category}
                  label={category}
                  active
                  onClick={() => handleCategoryClick(category)}
                />
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Category Stats Modal */}
      {showCategoryModal && selectedCategory && selectedCategoryDetails && selectedCategoryRateLabel && (
          <div className="fixed inset-0 bg-black/50 z-50 flex items-end justify-center" onClick={handleCloseModal}>
            <div className="bg-white rounded-t-2xl w-full max-w-[390px] max-h-[85vh] flex flex-col overflow-hidden animate-slide-up" onClick={(e) => e.stopPropagation()}>
              <div className="flex-shrink-0 bg-white border-b border-neutral-200 px-6 py-4 flex items-center justify-between">
                <h3 className="text-neutral-900">{selectedCategory}</h3>
                <button onClick={handleCloseModal} className="text-[#6B7280]">
                  ✕
                </button>
              </div>

              <div className="flex-1 overflow-y-auto p-6 space-y-6">
                <div>
                  <label className="block text-neutral-900 mb-3">Rate</label>
                  <p className="text-neutral-900">{selectedCategoryRateLabel}</p>
                  <p className="text-[#6B7280] text-sm mt-2">
                    {selectedCategoryDetails.rateType === "hourly"
                      ? "Your hourly rate for this service"
                      : "Your fixed project rate for this service"}
                  </p>
                </div>

                <div>
                  <label className="block text-neutral-900 mb-3">Performance</label>
                  <div className="grid grid-cols-2 gap-3">
                    <Card>
                      <div className="flex items-center gap-2 mb-1">
                        <Star size={16} className="fill-yellow-400 text-yellow-400" />
                        <span className="text-2xl text-neutral-900">{selectedCategoryDetails.rating}</span>
                      </div>
                      <p className="text-[#6B7280] text-sm">Rating</p>
                    </Card>

                    <Card>
                      <p className="text-2xl text-neutral-900 mb-1">{selectedCategoryDetails.completedJobs}</p>
                      <p className="text-[#6B7280] text-sm">Jobs completed</p>
                    </Card>
                  </div>
                  <p className="text-[#6B7280] text-sm mt-3">
                    {selectedCategoryDetails.reviewCount} reviews
                  </p>
                </div>

                <div>
                  <label className="block text-neutral-900 mb-3">
                    Service radius
                  </label>
                  <p className="text-neutral-900">{selectedCategoryDetails.serviceRadius} km</p>
                  <p className="text-[#6B7280] text-sm mt-2">
                    How far you're willing to travel for jobs in this category
                  </p>
                </div>

                <div>
                  <label className="block text-neutral-900 mb-3">Category Bio</label>
                  <p className="text-neutral-900 whitespace-pre-wrap">
                    {selectedCategoryDetails.bio || "No category bio yet."}
                  </p>
                </div>

                <button
                  onClick={handleCloseModal}
                  className="w-full py-3 bg-[#4F46E5] text-white rounded-lg"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
      )}

      {/* Seeker Stats Section */}
      {user.roles.isSeeker && (
        <div className="bg-white px-4 py-6 mb-4">
          <h3 className="text-neutral-900 mb-4">Seeker Profile</h3>
          <div className="grid grid-cols-3 gap-3">
            <Card>
              <p className="text-2xl text-neutral-900 mb-1">{user.seekerInfo.jobsPosted}</p>
              <p className="text-[#6B7280] text-sm">Jobs</p>
            </Card>

            <Card>
              <p className="text-2xl text-neutral-900 mb-1">{user.seekerInfo.completedJobs}</p>
              <p className="text-[#6B7280] text-sm">Completed</p>
            </Card>

            <Card>
              <div className="flex items-center gap-2 mb-1">
                <Star size={16} className="fill-yellow-400 text-yellow-400" />
                <span className="text-2xl text-neutral-900">{user.seekerInfo.rating}</span>
              </div>
              <p className="text-[#6B7280] text-sm">Rating</p>
            </Card>
          </div>
        </div>
      )}

      {/* Ghost Mode Toggle - Only show for Taskers */}
      {user.roles.isTasker && (
        <div className={`bg-white mb-4 px-4 py-4 ${!hasActiveSubscription ? 'opacity-50' : ''}`}>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Moon size={20} className="text-[#6B7280]" />
              <div>
                <p className="text-neutral-900">Ghost Mode</p>
                <p className="text-[#6B7280] text-sm">
                  {!hasActiveSubscription
                    ? "Locked on without an active subscription"
                    : "Hide from Seeker search"}
                </p>
              </div>
            </div>
            <button
              onClick={async () => {
                if (!hasActiveSubscription) return;
                await setGhostMode({ ghostMode: !isGhostMode });
              }}
              disabled={!hasActiveSubscription}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                isGhostMode ? "bg-[#4F46E5]" : "bg-neutral-300"
              } ${!hasActiveSubscription ? 'cursor-not-allowed' : ''}`}
            >
              <span
                className={`inline-block size-4 transform rounded-full bg-white transition-transform ${
                  isGhostMode ? "translate-x-6" : "translate-x-1"
                }`}
              />
            </button>
          </div>
        </div>
      )}

      {/* Help & Sign Out */}
      <div className="bg-white divide-y divide-neutral-200 mb-4">
        <button
          onClick={() => onNavigate("help")}
          className="w-full px-4 py-4 flex items-center justify-between active:bg-neutral-50"
        >
          <div className="flex items-center gap-3">
            <HelpCircle size={20} className="text-[#6B7280]" />
            <span className="text-neutral-900">Help & Support</span>
          </div>
          <ChevronRight size={20} className="text-[#6B7280]" />
        </button>

        <button 
          onClick={() => signOut()}
          className="w-full px-4 py-4 flex items-center gap-3 active:bg-neutral-50 text-[#DC2626]"
        >
          <LogOut size={20} />
          <span>Sign Out</span>
        </button>
      </div>

      <div className="px-4 py-6 text-center">
        <p className="text-[#6B7280] text-sm">Version 1.0.0</p>
      </div>

      <BottomNav active="profile" onNavigate={onNavigate} />
    </div>
  );
}
