import { Home, Search, PlusCircle, MessageCircle, User, Briefcase } from "lucide-react";

export function BottomNav({ active = "home", onNavigate }: { active?: string; onNavigate?: (tab: string) => void }) {
  const tabs = [
    { id: "home", label: "Seek", icon: Search },
    { id: "jobs", label: "Jobs", icon: Briefcase },
    { id: "messages", label: "Messages", icon: MessageCircle },
    { id: "profile", label: "Profile", icon: User }
  ];

  return (
    <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-neutral-200 safe-area-bottom">
      <div className="max-w-[390px] mx-auto flex">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const isActive = active === tab.id;
          
          return (
            <button
              key={tab.id}
              onClick={() => onNavigate?.(tab.id)}
              className="flex-1 flex flex-col items-center py-2 gap-1"
            >
              <Icon
                size={24}
                className={isActive ? "text-[#4F46E5]" : "text-[#6B7280]"}
              />
              <span className={`text-xs ${isActive ? "text-[#4F46E5]" : "text-[#6B7280]"}`}>
                {tab.label}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}