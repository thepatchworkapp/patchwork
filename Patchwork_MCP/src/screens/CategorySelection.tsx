import { useState, useMemo } from "react";
import { ArrowLeft, Search, ArrowRight, Loader2 } from "lucide-react";
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

interface CategorySelectionProps {
  onBack: () => void;
  onConfirm: (categories: string[]) => void;
  preSelected?: string[];
}

export function CategorySelection({ onBack, onConfirm, preSelected = [] }: CategorySelectionProps) {
  const [selectedCategories, setSelectedCategories] = useState<string[]>(preSelected);
  const [searchQuery, setSearchQuery] = useState("");

  const backendCategories = useQuery(api.categories.listCategories);

  const categoryGroups = useMemo(() => {
    if (!backendCategories) return [];

    const groupMap = new Map<string, { emoji: string; label: string }[]>();

    for (const cat of backendCategories) {
      const group = cat.group ?? "Other";
      if (!groupMap.has(group)) {
        groupMap.set(group, []);
      }
      groupMap.get(group)!.push({
        emoji: cat.emoji ?? "📋",
        label: cat.name,
      });
    }

    return Array.from(groupMap.entries()).map(([title, items]) => ({
      title,
      items,
    }));
  }, [backendCategories]);

  const totalCategories = backendCategories?.length ?? 0;

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

  if (backendCategories === undefined) {
    return (
      <div className="min-h-screen bg-white flex items-center justify-center">
        <Loader2 className="w-8 h-8 text-[#4F46E5] animate-spin" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white flex flex-col w-full max-w-full">
      <div className="bg-[#4F46E5] text-white px-4 pt-4 pb-6 w-full">
        <button type="button" onClick={onBack} className="mb-6">
          <ArrowLeft size={24} />
        </button>
        <h1 className="mb-2">Select a category</h1>
        <p className="text-white/80">{totalCategories} categories to browse.</p>
      </div>

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

      <div className="flex-1 overflow-y-auto pb-24">
        {filteredGroups.map((group) => (
          <div key={group.title}>
            <div className="border-t border-neutral-200" />
            
            <div className="px-4 py-3">
              <h3 className="text-[#6B7280]">{group.title}</h3>
            </div>
            
            <div className="px-4 pb-4 overflow-x-auto">
              <div className="flex gap-4 pb-2">
                {group.items.map((item) => (
                  <button
                    type="button"
                    key={item.label}
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

      <div className="fixed bottom-0 left-0 right-0 bg-[#4F46E5] px-4 py-4 flex items-center justify-between w-full">
        <span className="text-white text-lg">
          {selectedCategories.length} selected
        </span>
        <button
          type="button"
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
