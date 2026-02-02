import { useState } from "react";
import { Calendar, DollarSign } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Avatar } from "../components/patchwork/Avatar";
import { Badge } from "../components/patchwork/Badge";

export function Jobs({ onNavigate }: { onNavigate: (screen: string) => void }) {
  const [activeTab, setActiveTab] = useState<"in-progress" | "completed">("in-progress");

  const inProgressJobs = [
    {
      id: "1",
      taskerName: "Alex Chen",
      taskerAvatar: "",
      category: "Plumbing",
      rate: 85,
      rateType: "hourly" as const,
      startDate: "Dec 18, 2024",
      notes: "Kitchen sink repair - bringing own tools"
    },
    {
      id: "2",
      taskerName: "Maria Garcia",
      taskerAvatar: "",
      category: "House Cleaning",
      rate: 250,
      rateType: "fixed" as const,
      startDate: "Dec 20, 2024",
      notes: "Deep clean 3-bedroom apartment"
    },
    {
      id: "3",
      taskerName: "David Kim",
      taskerAvatar: "",
      category: "Electrical",
      rate: 95,
      rateType: "hourly" as const,
      startDate: "Dec 22, 2024",
      notes: "Install ceiling fan in living room"
    }
  ];

  const completedJobs = [
    {
      id: "4",
      taskerName: "Sarah Johnson",
      taskerAvatar: "",
      category: "Moving Help",
      rate: 400,
      rateType: "fixed" as const,
      completedDate: "Dec 10, 2024",
      notes: "2-bedroom apartment move - 3 hours"
    },
    {
      id: "5",
      taskerName: "James Wilson",
      taskerAvatar: "",
      category: "Lawn Care",
      rate: 60,
      rateType: "hourly" as const,
      completedDate: "Dec 5, 2024",
      notes: "Mowing and edging front/back yard"
    },
    {
      id: "6",
      taskerName: "Emma Davis",
      taskerAvatar: "",
      category: "Painting",
      rate: 500,
      rateType: "fixed" as const,
      completedDate: "Nov 28, 2024",
      notes: "Two rooms - walls only, paint included"
    },
    {
      id: "7",
      taskerName: "Michael Brown",
      taskerAvatar: "",
      category: "Furniture Assembly",
      rate: 55,
      rateType: "hourly" as const,
      completedDate: "Nov 15, 2024",
      notes: "IKEA bedroom furniture set"
    }
  ];

  const jobs = activeTab === "in-progress" ? inProgressJobs : completedJobs;

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      <AppBar title="Jobs" />

      {/* Tabs */}
      <div className="bg-white border-b border-neutral-200">
        <div className="flex">
          <button
            onClick={() => setActiveTab("in-progress")}
            className={`flex-1 py-4 text-center border-b-2 transition-colors ${
              activeTab === "in-progress"
                ? "border-[#4F46E5] text-[#4F46E5]"
                : "border-transparent text-[#6B7280]"
            }`}
          >
            In Progress
          </button>
          <button
            onClick={() => setActiveTab("completed")}
            className={`flex-1 py-4 text-center border-b-2 transition-colors ${
              activeTab === "completed"
                ? "border-[#4F46E5] text-[#4F46E5]"
                : "border-transparent text-[#6B7280]"
            }`}
          >
            Completed
          </button>
        </div>
      </div>

      {/* Jobs List */}
      <div className="p-4 space-y-3">
        {jobs.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-[#6B7280]">
              {activeTab === "in-progress"
                ? "No jobs in progress"
                : "No completed jobs yet"}
            </p>
          </div>
        ) : (
          jobs.map((job) => (
            <div
              key={job.id}
              className="bg-white rounded-lg p-4 border border-neutral-200"
            >
              {/* Header */}
              <div className="flex items-start gap-3 mb-3">
                <Avatar src={job.taskerAvatar} alt={job.taskerName} size="md" />
                <div className="flex-1 min-w-0">
                  <p className="text-neutral-900 mb-1">{job.taskerName}</p>
                  <Badge variant="neutral">{job.category}</Badge>
                </div>
              </div>

              {/* Rate */}
              <div className="flex items-center gap-2 mb-2 text-[#6B7280]">
                <DollarSign size={16} />
                <span className="text-sm">
                  ${job.rate}
                  {job.rateType === "hourly" ? "/hour" : " fixed"}
                </span>
              </div>

              {/* Date */}
              <div className="flex items-center gap-2 mb-3 text-[#6B7280]">
                <Calendar size={16} />
                <span className="text-sm">
                  {activeTab === "in-progress"
                    ? `Starts ${(job as typeof inProgressJobs[0]).startDate}`
                    : `Completed ${(job as typeof completedJobs[0]).completedDate}`}
                </span>
              </div>

              {/* Notes */}
              {job.notes && (
                <div className="bg-neutral-50 rounded p-3">
                  <p className="text-sm text-[#6B7280]">{job.notes}</p>
                </div>
              )}
            </div>
          ))
        )}
      </div>

      <BottomNav active="jobs" onNavigate={onNavigate} />
    </div>
  );
}
