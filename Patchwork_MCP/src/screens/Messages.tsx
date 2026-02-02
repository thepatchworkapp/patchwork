import { Search, Lock } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Avatar } from "../components/patchwork/Avatar";
import { Badge } from "../components/patchwork/Badge";
import { Button } from "../components/patchwork/Button";
import { useState } from "react";

export function Messages({ onNavigate, onOpenChat, isTasker = false }: { onNavigate: (screen: string) => void; onOpenChat: () => void; isTasker?: boolean }) {
  const [activeTab, setActiveTab] = useState<"seeker" | "tasker">("seeker");
  const [showTaskerSignupModal, setShowTaskerSignupModal] = useState(false);

  const seekerConversations = [
    { name: "Alex Chen", lastMessage: "I can come by tomorrow at 2pm", time: "10m ago", unread: 2 },
    { name: "Maria Garcia", lastMessage: "Thanks for choosing me! See you on...", time: "2h ago", unread: 0 },
    { name: "David Kim", lastMessage: "What time works best for you?", time: "1d ago", unread: 1 },
    { name: "Sarah Johnson", lastMessage: "Job completed successfully!", time: "3d ago", unread: 0 }
  ];

  const taskerConversations = [
    { name: "Emily Brown", lastMessage: "When can you start the project?", time: "5m ago", unread: 1 },
    { name: "James Wilson", lastMessage: "Great work! Thanks!", time: "1h ago", unread: 0 }
  ];

  const conversations = activeTab === "seeker" ? seekerConversations : taskerConversations;

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      <AppBar title="Messages" />

      {/* Tabs */}
      <div className="bg-white border-b border-neutral-200">
        <div className="flex">
          <button
            onClick={() => setActiveTab("seeker")}
            className={`flex-1 py-4 text-center relative ${
              activeTab === "seeker"
                ? "text-[#4F46E5]"
                : "text-[#6B7280]"
            }`}
          >
            Seeker
            {activeTab === "seeker" && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#4F46E5]" />
            )}
          </button>
          <button
            onClick={() => {
              if (isTasker) {
                setActiveTab("tasker");
              } else {
                setShowTaskerSignupModal(true);
              }
            }}
            className={`flex-1 py-4 text-center relative flex items-center justify-center gap-2 ${
              !isTasker
                ? "text-[#9CA3AF] cursor-not-allowed"
                : activeTab === "tasker"
                ? "text-[#4F46E5]"
                : "text-[#6B7280]"
            }`}
          >
            {!isTasker && <Lock size={16} />}
            Tasker
            {activeTab === "tasker" && isTasker && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#4F46E5]" />
            )}
          </button>
        </div>
      </div>

      {/* Locked Message for Tasker Tab */}
      {activeTab === "tasker" && !isTasker && (
        <div className="px-4 py-8 text-center">
          <div className="inline-flex items-center justify-center size-12 rounded-full bg-neutral-100 mb-3">
            <Lock size={24} className="text-[#6B7280]" />
          </div>
          <h3 className="text-neutral-900 mb-2">Become a Tasker</h3>
          <p className="text-[#6B7280] text-sm mb-4">
            Sign up as a Tasker to receive job requests and chat with Seekers
          </p>
          <button
            onClick={() => onNavigate("profile")}
            className="px-6 py-3 bg-[#4F46E5] text-white rounded-lg"
          >
            Go to Profile
          </button>
        </div>
      )}

      {/* Search and Conversations */}
      {(activeTab === "seeker" || isTasker) && (
        <>
          <div className="px-4 py-4 bg-white border-b border-neutral-200">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]" size={20} />
              <input
                type="text"
                placeholder="Search conversations..."
                className="w-full pl-10 pr-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1"
              />
            </div>
          </div>

          <div className="divide-y divide-neutral-200">
            {conversations.map((conv, i) => (
              <button
                key={i}
                onClick={onOpenChat}
                className="w-full px-4 py-4 bg-white active:bg-neutral-50 flex items-start gap-3 text-left"
              >
                <div className="relative">
                  <Avatar src="" alt={conv.name} size="md" />
                  {conv.unread > 0 && (
                    <div className="absolute -top-1 -right-1 size-5 rounded-full bg-[#DC2626] text-white text-xs flex items-center justify-center">
                      {conv.unread}
                    </div>
                  )}
                </div>

                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between mb-1">
                    <p className="text-neutral-900">{conv.name}</p>
                    <span className="text-[#6B7280] text-sm">{conv.time}</span>
                  </div>
                  <p className={`text-sm truncate ${conv.unread > 0 ? "text-neutral-900" : "text-[#6B7280]"}`}>
                    {conv.lastMessage}
                  </p>
                </div>
              </button>
            ))}
          </div>
        </>
      )}

      <BottomNav active="messages" onNavigate={onNavigate} />

      {/* Tasker Signup Modal */}
      {showTaskerSignupModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-[358px]">
            <div className="p-6 text-center">
              <div className="inline-flex items-center justify-center size-16 rounded-full bg-indigo-100 mb-4">
                <Lock size={32} className="text-[#4F46E5]" />
              </div>
              
              <h3 className="text-neutral-900 mb-3">Become a Tasker</h3>
              
              <p className="text-[#6B7280] text-sm mb-6">
                Do you have a service to provide? Sign up as a Tasker to:
              </p>
              
              <div className="text-left space-y-3 mb-6">
                <div className="flex gap-3">
                  <div className="size-5 rounded-full bg-indigo-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                    <div className="size-2 rounded-full bg-[#4F46E5]" />
                  </div>
                  <p className="text-sm text-neutral-900">Receive job requests from clients in your area</p>
                </div>
                <div className="flex gap-3">
                  <div className="size-5 rounded-full bg-indigo-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                    <div className="size-2 rounded-full bg-[#4F46E5]" />
                  </div>
                  <p className="text-sm text-neutral-900">Set your own rates and schedule</p>
                </div>
                <div className="flex gap-3">
                  <div className="size-5 rounded-full bg-indigo-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                    <div className="size-2 rounded-full bg-[#4F46E5]" />
                  </div>
                  <p className="text-sm text-neutral-900">Build your reputation through real reviews</p>
                </div>
                <div className="flex gap-3">
                  <div className="size-5 rounded-full bg-indigo-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                    <div className="size-2 rounded-full bg-[#4F46E5]" />
                  </div>
                  <p className="text-sm text-neutral-900">Connect with clients within 250km</p>
                </div>
              </div>
            </div>

            <div className="p-6 border-t border-neutral-200 flex gap-3">
              <Button variant="secondary" fullWidth onClick={() => setShowTaskerSignupModal(false)}>
                Not Now
              </Button>
              <Button 
                variant="primary" 
                fullWidth 
                onClick={() => {
                  setShowTaskerSignupModal(false);
                  onNavigate("tasker-onboarding-1");
                }}
              >
                Continue
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}