import { useState } from "react";
import { Search } from "lucide-react";
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { AppBar } from "../components/patchwork/AppBar";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Card } from "../components/patchwork/Card";
import { Chip } from "../components/patchwork/Chip";

export function Categories({ onNavigate, onBack }: { onNavigate: (screen: string) => void; onBack: () => void }) {
  const [filter, setFilter] = useState("all");
  
  const filters = ["All", "Home", "Business", "Personal", "Outdoor"];
  
  const backendCategories = useQuery(api.categories.listCategories);

  const categories = (backendCategories ?? []).map(c => ({
    name: c.name,
    icon: c.emoji ?? "📋",
  }));

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      <AppBar title="Browse Categories" onBack={onBack} />

      <div className="px-4 py-4 bg-white border-b border-neutral-200">
        <div className="relative mb-4">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]" size={20} />
          <input
            type="text"
            placeholder="Search categories..."
            className="w-full pl-10 pr-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1"
          />
        </div>

        <div className="flex gap-2 overflow-x-auto pb-2 -mx-4 px-4">
          {filters.map((f) => (
            <Chip
              key={f}
              label={f}
              active={filter === f.toLowerCase()}
              onClick={() => setFilter(f.toLowerCase())}
            />
          ))}
        </div>
      </div>

      <div className="p-4">
        <p className="text-[#6B7280] mb-4">{categories.length} categories available</p>
        
        <div className="grid grid-cols-2 gap-3">
          {categories.map((cat) => (
            <Card key={cat.name} onClick={() => onNavigate("browse")}>
              <div className="text-center">
                <div className="text-4xl mb-2">{cat.icon}</div>
                <p className="text-neutral-900 mb-1">{cat.name}</p>
              </div>
            </Card>
          ))}
        </div>
      </div>

      <BottomNav active="browse" onNavigate={onNavigate} />
    </div>
  );
}
