import { ChevronRight, Settings, HelpCircle, LogOut, MapPin, Star, Shield, Edit2, Camera, Lock, Plus, DollarSign, Trash2, Moon } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Avatar } from "../components/patchwork/Avatar";
import { Button } from "../components/patchwork/Button";
import { Badge } from "../components/patchwork/Badge";
import { Card } from "../components/patchwork/Card";
import { Chip } from "../components/patchwork/Chip";
import { useState, useEffect } from "react";
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { signOut } from "../lib/auth";

export function Profile({ 
  onNavigate, 
  onSwitchToTasker, 
  isTasker = false, 
  userPhoto, 
  taskerCategories = [], 
  taskerCategoryBio = "",
  taskerCategoryRateType = "hourly",
  taskerCategoryHourlyRate = "",
  taskerCategoryFixedRate = "",
  taskerCategoryServiceRadius = 50,
  taskerCategoryPhotos = [],
  pendingNewCategory = null,
  onCategoryModalClosed = () => {},
  onCategoryRemoved = () => {},
  subscriptionPlan = "none"
}: { 
  onNavigate: (screen: string) => void; 
  onSwitchToTasker: () => void; 
  isTasker?: boolean; 
  userPhoto?: string; 
  taskerCategories?: string[]; 
  taskerCategoryBio?: string;
  taskerCategoryRateType?: "hourly" | "fixed";
  taskerCategoryHourlyRate?: string;
  taskerCategoryFixedRate?: string;
  taskerCategoryServiceRadius?: number;
  taskerCategoryPhotos?: string[];
  pendingNewCategory?: string | null;
  onCategoryModalClosed?: () => void;
  onCategoryRemoved?: (category: string) => void;
  subscriptionPlan?: "none" | "basic" | "premium";
}) {
  const [showCategoryModal, setShowCategoryModal] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [isEditingCategory, setIsEditingCategory] = useState(false);
  const [categoryPhotos, setCategoryPhotos] = useState<string[]>([]);
  const [categoryRate, setCategoryRate] = useState("");
  const [categoryRateType, setCategoryRateType] = useState<"hourly" | "fixed">(taskerCategoryRateType);
  const [categoryRadius, setCategoryRadius] = useState(taskerCategoryServiceRadius);
  const [categoryBio, setCategoryBio] = useState(taskerCategoryBio);
  
  // Ghost mode state - derive subscription status from prop
  const [isGhostMode, setIsGhostMode] = useState(subscriptionPlan === "none"); // Ghost mode when no subscription
  const hasActiveSubscription = subscriptionPlan !== "none"; // Has subscription if not "none"

  // Update ghost mode when subscription changes
  useEffect(() => {
    // When subscription is activated, turn off ghost mode
    if (subscriptionPlan !== "none") {
      setIsGhostMode(false);
    }
  }, [subscriptionPlan]);

  // Auto-open modal for pending new category
  useEffect(() => {
    if (pendingNewCategory) {
      handleCategoryClick(pendingNewCategory);
    }
  }, [pendingNewCategory]);

  // Initialize rate based on type when modal opens
  const handleCategoryClick = (category: string) => {
    setSelectedCategory(category);
    
    // For the first category (from onboarding), use the synced data
    if (taskerCategories.length > 0 && category === taskerCategories[0]) {
      setCategoryRateType(taskerCategoryRateType);
      setCategoryRate(taskerCategoryRateType === "hourly" ? taskerCategoryHourlyRate : taskerCategoryFixedRate);
      setCategoryRadius(taskerCategoryServiceRadius);
      setCategoryBio(taskerCategoryBio);
      setCategoryPhotos(taskerCategoryPhotos);
      setIsEditingCategory(false);
    } else {
      // For additional categories, use defaults and open in edit mode
      setCategoryRateType("hourly");
      setCategoryRate("");
      setCategoryRadius(50);
      setCategoryBio("");
      setCategoryPhotos([]);
      setIsEditingCategory(true);
    }
    
    setShowCategoryModal(true);
  };

  const handleCloseModal = () => {
    setShowCategoryModal(false);
    setIsEditingCategory(false);
    onCategoryModalClosed();
  };

  const handleRemoveCategory = () => {
    if (selectedCategory) {
      onCategoryRemoved(selectedCategory);
      handleCloseModal();
    }
  };

  // Fetch real user data from Convex
  const userData = useQuery(api.users.getCurrentUser);
  const taskerProfile = useQuery(api.taskers.getTaskerProfile);

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
      categories: taskerProfile.categories?.map((c: any) => c.categoryName) || [],
      rating: taskerProfile.rating,
      reviewCount: taskerProfile.reviewCount,
      completedJobs: taskerProfile.completedJobs,
      responseTime: taskerProfile.responseTime || "N/A",
      serviceRadius: taskerProfile.categories[0]?.serviceRadius || 0,
      verified: taskerProfile.verified,
      hourlyRate: taskerProfile.categories[0]?.hourlyRate 
        ? `$${(taskerProfile.categories[0].hourlyRate / 100).toFixed(0)}/hr`
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
      jobsPosted: 0, // TODO: Get from seekerProfile when implemented
      completedJobs: 0,
      rating: 0
    }
  };

  const categoryStats: Record<string, { rating: number; reviews: number; jobs: number }> = {};
  if (taskerProfile?.categories) {
    taskerProfile.categories.forEach((cat: any) => {
      categoryStats[cat.categoryName] = {
        rating: cat.rating,
        reviews: cat.reviewCount,
        jobs: cat.completedJobs
      };
    });
  }

  const menuItems = [
    { icon: "👤", label: "Personal Info", screen: "profile-edit" },
    { icon: "📍", label: "Saved Addresses", screen: "addresses" },
    { icon: "⭐", label: "Favourite Taskers", screen: "favourites" },
    { icon: "📋", label: "Job History", screen: "job-history" },
    { icon: "💳", label: "Payment Methods", screen: "payment" },
  ];

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      <AppBar
        title="Profile"
        action={
          <button onClick={() => onNavigate("settings")}>
            <Settings size={20} className="text-neutral-900" />
          </button>
        }
      />

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
            {!isGhostMode && (
              <button className="absolute -bottom-1 -right-1 size-8 rounded-full bg-[#4F46E5] text-white flex items-center justify-center shadow-lg">
                <Camera size={16} />
              </button>
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

        {/* Activate Subscription Button - Only show if no active subscription */}
        {user.roles.isTasker && !hasActiveSubscription && (
          <Button
            variant="primary"
            fullWidth
            onClick={() => {
              setIsGhostMode(false);
              onNavigate("subscriptions");
            }}
          >
            Activate a subscription
          </Button>
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
              <button 
                onClick={() => onNavigate("category-selection")}
                className="text-[#4F46E5] flex items-center justify-center size-8 rounded-full hover:bg-[#4F46E5]/10 transition-colors"
              >
                <Plus size={20} />
              </button>
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
      {showCategoryModal && selectedCategory && (() => {
        const stats = categoryStats[selectedCategory as keyof typeof categoryStats] || { rating: 0, reviews: 0, jobs: 0 };
        return (
          <div className="fixed inset-0 bg-black/50 z-50 flex items-end justify-center" onClick={handleCloseModal}>
            <div className="bg-white rounded-t-2xl w-full max-w-[390px] max-h-[85vh] flex flex-col overflow-hidden animate-slide-up" onClick={(e) => e.stopPropagation()}>
              {/* Header - Fixed */}
              <div className="flex-shrink-0 bg-white border-b border-neutral-200 px-6 py-4 flex items-center justify-between">
                <h3 className="text-neutral-900">{selectedCategory}</h3>
                <div className="flex items-center gap-3">
                  {!isEditingCategory && (
                    <button
                      onClick={() => setIsEditingCategory(true)}
                      className="text-[#4F46E5] text-sm flex items-center gap-1"
                    >
                      <Edit2 size={14} />
                      <span>Edit</span>
                    </button>
                  )}
                  <button onClick={handleCloseModal} className="text-[#6B7280]">
                    ✕
                  </button>
                </div>
              </div>

              {/* Scrollable Content */}
              <div className="flex-1 overflow-y-auto p-6 space-y-6">
                {/* Photos Section */}
                <div>
                  <label className="block text-neutral-900 mb-3">Photos (up to 10)</label>
                  <div className="grid grid-cols-3 gap-3">
                    {categoryPhotos.map((photo, index) => (
                      <div key={index} className="relative aspect-square bg-neutral-100 rounded-lg overflow-hidden">
                        <img src={photo} alt={`Category photo ${index + 1}`} className="w-full h-full object-cover" />
                        {isEditingCategory && (
                          <button
                            onClick={() => setCategoryPhotos(categoryPhotos.filter((_, i) => i !== index))}
                            className="absolute top-1 right-1 size-6 rounded-full bg-black/60 text-white flex items-center justify-center text-xs"
                          >
                            ✕
                          </button>
                        )}
                      </div>
                    ))}
                    {categoryPhotos.length < 10 && isEditingCategory && (
                      <button className="aspect-square bg-neutral-100 rounded-lg flex items-center justify-center border-2 border-dashed border-neutral-300">
                        <div className="text-center">
                          <Plus size={24} className="text-[#6B7280] mx-auto mb-1" />
                          <p className="text-xs text-[#6B7280]">Add photo</p>
                        </div>
                      </button>
                    )}
                  </div>
                </div>

                {/* Rate Section */}
                <div>
                  <label className="block text-neutral-900 mb-3">Rate</label>
                  <div className="space-y-3">
                    <div className="flex gap-2">
                      <button
                        onClick={() => isEditingCategory && setCategoryRateType("hourly")}
                        className={`flex-1 py-2 px-4 rounded-lg border-2 transition-colors ${
                          categoryRateType === "hourly"
                            ? "border-[#4F46E5] bg-[#4F46E5]/5 text-[#4F46E5]"
                            : "border-neutral-200 text-[#6B7280]"
                        }`}
                        disabled={!isEditingCategory}
                      >
                        Hourly
                      </button>
                      <button
                        onClick={() => isEditingCategory && setCategoryRateType("fixed")}
                        className={`flex-1 py-2 px-4 rounded-lg border-2 transition-colors ${
                          categoryRateType === "fixed"
                            ? "border-[#4F46E5] bg-[#4F46E5]/5 text-[#4F46E5]"
                            : "border-neutral-200 text-[#6B7280]"
                        }`}
                        disabled={!isEditingCategory}
                      >
                        Fixed
                      </button>
                    </div>
                    {categoryRateType === "hourly" ? (
                      <div className="relative">
                        <DollarSign size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]" />
                        <input
                          type="number"
                          value={categoryRate}
                          onChange={(e) => setCategoryRate(e.target.value)}
                          disabled={!isEditingCategory}
                          className="w-full pl-10 pr-16 py-3 rounded-lg border border-neutral-200 disabled:bg-neutral-50 disabled:text-neutral-900"
                          placeholder="0.00"
                        />
                        <span className="absolute right-4 top-1/2 -translate-y-1/2 text-[#6B7280]">/hr</span>
                      </div>
                    ) : (
                      <div className="relative">
                        <DollarSign size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]" />
                        <input
                          type="number"
                          value={categoryRate}
                          onChange={(e) => setCategoryRate(e.target.value)}
                          disabled={!isEditingCategory}
                          className="w-full pl-10 pr-4 py-3 rounded-lg border border-neutral-200 disabled:bg-neutral-50 disabled:text-neutral-900"
                          placeholder="0.00"
                        />
                      </div>
                    )}
                    <p className="text-[#6B7280] text-sm">
                      {categoryRateType === "hourly" 
                        ? "Your hourly rate for this service"
                        : "Your fixed project rate for this service"}
                    </p>
                  </div>
                </div>

                {/* Stats Grid */}
                <div>
                  <label className="block text-neutral-900 mb-3">Performance</label>
                  <div className="grid grid-cols-2 gap-3">
                    <Card>
                      <div className="flex items-center gap-2 mb-1">
                        <Star size={16} className="fill-yellow-400 text-yellow-400" />
                        <span className="text-2xl text-neutral-900">{stats.rating}</span>
                      </div>
                      <p className="text-[#6B7280] text-sm">Rating</p>
                    </Card>

                    <Card>
                      <p className="text-2xl text-neutral-900 mb-1">{stats.jobs}</p>
                      <p className="text-[#6B7280] text-sm">Jobs completed</p>
                    </Card>
                  </div>
                </div>

                {/* Service Radius */}
                <div>
                  <label className="block text-neutral-900 mb-3">
                    Service radius: {categoryRadius} km
                  </label>
                  <div className="relative px-2">
                    <input
                      type="range"
                      min="1"
                      max="250"
                      value={categoryRadius}
                      onChange={(e) => setCategoryRadius(Number(e.target.value))}
                      disabled={!isEditingCategory}
                      className="w-full h-2 bg-neutral-200 rounded-lg appearance-none cursor-pointer disabled:cursor-not-allowed [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:size-5 [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-[#4F46E5] [&::-moz-range-thumb]:size-5 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:bg-[#4F46E5] [&::-moz-range-thumb]:border-0"
                    />
                    <div className="flex justify-between mt-2">
                      <span className="text-[#6B7280] text-sm">1 km</span>
                      <span className="text-[#6B7280] text-sm">250 km</span>
                    </div>
                  </div>
                  <p className="text-[#6B7280] text-sm mt-2">
                    How far you're willing to travel for jobs in this category
                  </p>
                </div>

                {/* Bio Section */}
                <div>
                  <label className="block text-neutral-900 mb-3">Category Bio</label>
                  <textarea
                    value={categoryBio}
                    onChange={(e) => setCategoryBio(e.target.value)}
                    disabled={!isEditingCategory}
                    rows={4}
                    className="w-full px-4 py-3 rounded-lg border border-neutral-200 disabled:bg-neutral-50 disabled:text-neutral-900 resize-none"
                    placeholder="Describe your services for this category..."
                  />
                  <p className="text-xs text-[#6B7280] mt-1">{categoryBio.length} / 500 characters</p>
                </div>

                {/* Action Buttons */}
                {isEditingCategory ? (
                  <div className="space-y-3">
                    <div className="flex gap-3">
                      <button
                        onClick={() => setIsEditingCategory(false)}
                        className="flex-1 py-3 bg-neutral-100 text-neutral-900 rounded-lg"
                      >
                        Cancel
                      </button>
                      <button
                        onClick={() => setIsEditingCategory(false)}
                        className="flex-1 py-3 bg-[#4F46E5] text-white rounded-lg"
                      >
                        Save Changes
                      </button>
                    </div>
                    <button
                      onClick={handleRemoveCategory}
                      className="w-full py-3 border border-[#DC2626] text-[#DC2626] rounded-lg flex items-center justify-center gap-2 hover:bg-[#DC2626]/5 transition-colors"
                    >
                      <Trash2 size={18} />
                      <span>Remove Category</span>
                    </button>
                  </div>
                ) : (
                  <button
                    onClick={handleCloseModal}
                    className="w-full py-3 bg-[#4F46E5] text-white rounded-lg"
                  >
                    Close
                  </button>
                )}
              </div>
            </div>
          </div>
        );
      })()}

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

      {/* Menu Items */}
      <div className="bg-white divide-y divide-neutral-200 mb-4">
        {menuItems.map((item, i) => (
          <button
            key={i}
            onClick={() => onNavigate(item.screen)}
            className="w-full px-4 py-4 flex items-center justify-between active:bg-neutral-50"
          >
            <div className="flex items-center gap-3">
              <span className="text-2xl">{item.icon}</span>
              <span className="text-neutral-900">{item.label}</span>
            </div>
            <ChevronRight size={20} className="text-[#6B7280]" />
          </button>
        ))}
      </div>

      {/* Ghost Mode Toggle - Only show for Taskers */}
      {user.roles.isTasker && (
        <div className={`bg-white mb-4 px-4 py-4 ${!hasActiveSubscription ? 'opacity-50' : ''}`}>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Moon size={20} className="text-[#6B7280]" />
              <div>
                <p className="text-neutral-900">Ghost Mode</p>
                <p className="text-[#6B7280] text-sm">
                  {!hasActiveSubscription ? "Requires active subscription" : "Hide from Seeker search"}
                </p>
              </div>
            </div>
            <button
              onClick={() => hasActiveSubscription && setIsGhostMode(!isGhostMode)}
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
