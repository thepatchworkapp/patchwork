import { useState } from "react";
import { Camera } from "lucide-react";
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Input } from "../components/patchwork/Input";
import { Chip } from "../components/patchwork/Chip";
import { Avatar } from "../components/patchwork/Avatar";

interface TaskerOnboarding1Props {
  onBack: () => void;
  onNext: () => void;
  onSeeAllCategories: () => void;
  userPhoto?: string;
  displayName: string;
  onDisplayNameChange: (name: string) => void;
  selectedCategories: string[];
  onCategoriesChange: (categories: string[]) => void;
}

export function TaskerOnboarding1({ 
  onBack, 
  onNext, 
  onSeeAllCategories,
  userPhoto,
  displayName,
  onDisplayNameChange,
  selectedCategories,
  onCategoriesChange
}: TaskerOnboarding1Props) {
  const backendCategories = useQuery(api.categories.listCategories);
  const allCategories = (backendCategories ?? []).map(c => c.name);

  const displayCategories = selectedCategories.length > 0
    ? [
        ...selectedCategories,
        ...allCategories.filter(cat => !selectedCategories.includes(cat)).slice(0, 10 - selectedCategories.length)
      ]
    : allCategories.slice(0, 10);

  const toggleCategory = (cat: string) => {
    onCategoriesChange(
      selectedCategories.includes(cat) 
        ? selectedCategories.filter(c => c !== cat) 
        : [cat]  // Only allow single selection
    );
  };

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="Become a Tasker" onBack={onBack} />

      <div className="flex-1 px-4 pt-6">
        <div className="mb-6">
          <div className="flex items-center gap-2 mb-6">
            <div className="size-8 rounded-full bg-[#4F46E5] text-white flex items-center justify-center">1</div>
            <div className="flex-1 h-1 bg-neutral-200" />
            <div className="size-8 rounded-full bg-neutral-200 text-[#6B7280] flex items-center justify-center">2</div>
            <div className="flex-1 h-1 bg-neutral-200" />
            <div className="size-8 rounded-full bg-neutral-200 text-[#6B7280] flex items-center justify-center">3</div>
          </div>
        </div>

        <h2 className="text-neutral-900 mb-2">Business basics</h2>
        <p className="text-[#6B7280] mb-6">Tell Seekers about your services</p>

        <div className="flex flex-col items-center mb-6">
          {userPhoto ? (
            <div className="relative">
              <Avatar src={userPhoto} alt="Profile" size="xl" />
              <button className="absolute -bottom-1 -right-1 size-8 rounded-full bg-[#4F46E5] text-white flex items-center justify-center shadow-lg">
                <Camera size={16} />
              </button>
            </div>
          ) : (
            <>
              <button className="size-24 rounded-lg bg-neutral-100 flex items-center justify-center mb-3">
                <Camera size={32} className="text-[#6B7280]" />
              </button>
              <p className="text-[#4F46E5]">Add profile photo</p>
            </>
          )}
        </div>

        <div className="space-y-4 mb-6">
          <Input
            label="Display name"
            placeholder="Your business or full name"
            value={displayName}
            onChange={(e) => onDisplayNameChange(e.target.value)}
          />

          <div>
            <label className="block mb-3 text-neutral-900">
              What service do you offer? (Select your most prominent, add more later)
            </label>
            <div className="flex flex-wrap gap-2">
              {displayCategories.map((cat) => (
                <Chip
                  key={cat}
                  label={cat}
                  active={selectedCategories.includes(cat)}
                  onClick={() => toggleCategory(cat)}
                />
              ))}
            </div>
            <button
              onClick={onSeeAllCategories}
              className="text-[#4F46E5] text-sm mt-3 underline"
            >
              See all categories
            </button>
          </div>
        </div>
      </div>

      <div className="p-4 border-t border-neutral-200">
        <Button variant="primary" fullWidth onClick={onNext} disabled={selectedCategories.length === 0}>
          Continue
        </Button>
      </div>
    </div>
  );
}