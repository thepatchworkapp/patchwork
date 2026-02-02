import { useState } from "react";
import { ArrowLeft, Search, ArrowRight } from "lucide-react";
import { Input } from "../components/patchwork/Input";

interface CategorySelectionProps {
  onBack: () => void;
  onConfirm: (categories: string[]) => void;
  preSelected?: string[];
}

export function CategorySelection({ onBack, onConfirm, preSelected = [] }: CategorySelectionProps) {
  const [selectedCategories, setSelectedCategories] = useState<string[]>(preSelected);
  const [searchQuery, setSearchQuery] = useState("");

  const categoryGroups = [
    {
      title: "Beauty",
      items: [
        { emoji: "💄", label: "Makeup Artist" },
        { emoji: "💇", label: "Hair Stylist" },
        { emoji: "👁️", label: "Lash Tech" },
        { emoji: "💅", label: "Nail Tech" },
        { emoji: "🧖", label: "Hair Removal" },
      ]
    },
    {
      title: "Home & Garden",
      items: [
        { emoji: "🔧", label: "Property Maintenance" },
        { emoji: "🎨", label: "Interior Painter" },
        { emoji: "🖌️", label: "Exterior Painter" },
        { emoji: "🚪", label: "Window Cleaner" },
        { emoji: "🏠", label: "Gutter Cleaning" },
        { emoji: "🌳", label: "Gardening" },
        { emoji: "🪴", label: "Landscaping" },
        { emoji: "🌿", label: "Lawn Care" },
      ]
    },
    {
      title: "Health & Wellbeing",
      items: [
        { emoji: "💆", label: "Massage Therapist" },
        { emoji: "🍏", label: "Nutritionist" },
        { emoji: "👵", label: "Care Giver" },
        { emoji: "🏋️", label: "Personal Trainer" },
        { emoji: "🏃", label: "Errand Runner" },
      ]
    },
    {
      title: "Pet Care",
      items: [
        { emoji: "🐕", label: "Dog Walking" },
        { emoji: "🐾", label: "Pet Sitting" },
        { emoji: "✂️", label: "Pet Grooming" },
        { emoji: "🐕‍🦺", label: "Pet Training" },
      ]
    },
    {
      title: "Home Services",
      items: [
        { emoji: "🔌", label: "Electrical" },
        { emoji: "🚰", label: "Plumbing" },
        { emoji: "🔨", label: "Handyman" },
        { emoji: "❄️", label: "HVAC" },
        { emoji: "🏗️", label: "Carpentry" },
        { emoji: "🏠", label: "Roofing" },
        { emoji: "🪟", label: "Flooring" },
        { emoji: "⚡", label: "Welding" },
        { emoji: "🧹", label: "Cleaning" },
        { emoji: "🐜", label: "Pest Control" },
      ]
    },
    {
      title: "Moving & Delivery",
      items: [
        { emoji: "📦", label: "Moving" },
        { emoji: "🚚", label: "Delivery" },
        { emoji: "📮", label: "Courier" },
      ]
    },
    {
      title: "Tech & Professional",
      items: [
        { emoji: "💻", label: "IT Support" },
        { emoji: "📱", label: "Phone Repair" },
        { emoji: "🖥️", label: "Computer Repair" },
        { emoji: "📚", label: "Tutoring" },
        { emoji: "🎓", label: "Music Lessons" },
        { emoji: "🎸", label: "Art Lessons" },
      ]
    },
    {
      title: "Automotive",
      items: [
        { emoji: "🚗", label: "Auto Repair" },
        { emoji: "🚙", label: "Car Detailing" },
        { emoji: "🔧", label: "Oil Change" },
        { emoji: "🚘", label: "Car Wash" },
      ]
    },
    {
      title: "Events & Creative",
      items: [
        { emoji: "📸", label: "Photography" },
        { emoji: "🎥", label: "Videography" },
        { emoji: "🎉", label: "Event Planning" },
        { emoji: "🍽️", label: "Catering" },
        { emoji: "🎤", label: "DJ Services" },
        { emoji: "🎭", label: "Entertainment" },
      ]
    },
    {
      title: "Repair & Appliances",
      items: [
        { emoji: "🔧", label: "Appliance Repair" },
        { emoji: "📺", label: "TV Mounting" },
        { emoji: "🛠️", label: "Furniture Assembly" },
      ]
    },
  ];

  const allCategories = categoryGroups.flatMap(group => 
    group.items.map(item => item.label)
  );

  const totalCategories = allCategories.length;

  const toggleCategory = (label: string) => {
    setSelectedCategories(prev =>
      prev.includes(label) ? prev.filter(cat => cat !== label) : [...prev, label]
    );
  };

  const filteredGroups = categoryGroups.map(group => ({
    ...group,
    items: group.items.filter(item =>
      item.label.toLowerCase().includes(searchQuery.toLowerCase())
    )
  })).filter(group => group.items.length > 0);

  return (
    <div className="min-h-screen bg-white flex flex-col w-full max-w-full">
      {/* Header */}
      <div className="bg-[#4F46E5] text-white px-4 pt-4 pb-6 w-full">
        <button onClick={onBack} className="mb-6">
          <ArrowLeft size={24} />
        </button>
        <h1 className="mb-2">Select a category</h1>
        <p className="text-white/80">{totalCategories} categories to browse.</p>
      </div>

      {/* Search */}
      <div className="px-4 py-4 bg-white sticky top-0 z-10 shadow-sm">
        <div className="relative">
          <input
            type="text"
            placeholder="Search categories..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-4 py-3 pr-12 bg-neutral-100 rounded-lg text-neutral-900 placeholder:text-[#6B7280] outline-none"
          />
          <Search className="absolute right-4 top-1/2 -translate-y-1/2 text-[#6B7280]" size={20} />
        </div>
      </div>

      {/* Categories */}
      <div className="flex-1 overflow-y-auto pb-24">
        {filteredGroups.map((group, groupIdx) => (
          <div key={groupIdx}>
            {/* Separator Line */}
            <div className="border-t border-neutral-200" />
            
            {/* Header */}
            <div className="px-4 py-3">
              <h3 className="text-[#6B7280]">{group.title}</h3>
            </div>
            
            {/* Category Items */}
            <div className="px-4 pb-4 overflow-x-auto">
              <div className="flex gap-4 pb-2">
                {group.items.map((item, idx) => (
                  <button
                    key={idx}
                    onClick={() => toggleCategory(item.label)}
                    className="flex-shrink-0 flex flex-col items-center gap-2 w-20"
                  >
                    <div className={`size-16 rounded-full flex items-center justify-center text-2xl transition-colors ${
                      selectedCategories.includes(item.label)
                        ? 'bg-[#4F46E5] ring-2 ring-[#4F46E5] ring-offset-2'
                        : 'bg-neutral-100'
                    }`}>
                      {item.emoji}
                    </div>
                    <span className={`text-xs text-center leading-tight ${
                      selectedCategories.includes(item.label)
                        ? 'text-[#4F46E5]'
                        : 'text-[#6B7280]'
                    }`}>
                      {item.label}
                    </span>
                  </button>
                ))}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Bottom Action Bar */}
      <div className="fixed bottom-0 left-0 right-0 bg-[#4F46E5] px-4 py-4 flex items-center justify-between w-full">
        <span className="text-white text-lg">
          {selectedCategories.length} selected
        </span>
        <button
          onClick={() => onConfirm(selectedCategories)}
          disabled={selectedCategories.length === 0}
          className="bg-white text-[#4F46E5] size-12 rounded-full flex items-center justify-center disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <ArrowRight size={24} />
        </button>
      </div>
    </div>
  );
}