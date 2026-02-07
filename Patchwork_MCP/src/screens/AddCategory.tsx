import { useState } from "react";
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";

interface AddCategoryProps {
  onBack: () => void;
  onAdd: (category: string) => void;
  existingCategories?: string[];
}

export function AddCategory({ onBack, onAdd, existingCategories = [] }: AddCategoryProps) {
  const [selectedCategory, setSelectedCategory] = useState<string>("");

  const backendCategories = useQuery(api.categories.listCategories);
  const allCategories = (backendCategories ?? []).map(c => c.name);

  const availableCategories = allCategories.filter(cat => !existingCategories.includes(cat));

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="Add Category" onBack={onBack} />

      <div className="flex-1 px-4 pt-6 pb-24 overflow-y-auto">
        <h2 className="text-neutral-900 mb-2">Choose a category</h2>
        <p className="text-[#6B7280] mb-6">Select one category to add to your profile</p>

        <div className="space-y-3">
          {availableCategories.map((category) => (
            <button
              key={category}
              onClick={() => setSelectedCategory(category)}
              className={`w-full px-4 py-4 rounded-lg border-2 text-left transition-all ${
                selectedCategory === category
                  ? "border-[#4F46E5] bg-[#4F46E5]/5"
                  : "border-neutral-200 hover:border-neutral-300"
              }`}
            >
              <div className="flex items-center justify-between">
                <span className={`${
                  selectedCategory === category ? "text-[#4F46E5]" : "text-neutral-900"
                }`}>
                  {category}
                </span>
                {selectedCategory === category && (
                  <div className="size-5 rounded-full bg-[#4F46E5] flex items-center justify-center">
                    <span className="text-white text-xs">✓</span>
                  </div>
                )}
              </div>
            </button>
          ))}
        </div>
      </div>

      <div className="fixed bottom-0 left-0 right-0 max-w-[390px] mx-auto p-4 bg-white border-t border-neutral-200">
        <Button 
          variant="primary" 
          fullWidth 
          onClick={() => selectedCategory && onAdd(selectedCategory)}
          disabled={!selectedCategory}
        >
          Continue
        </Button>
      </div>
    </div>
  );
}