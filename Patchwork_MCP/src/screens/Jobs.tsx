import { useState } from "react";
import { Calendar, DollarSign } from "lucide-react";
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Id } from "../../convex/_generated/dataModel";
import { AppBar } from "../components/patchwork/AppBar";
import { BottomNav } from "../components/patchwork/BottomNav";
import { Avatar } from "../components/patchwork/Avatar";
import { Badge } from "../components/patchwork/Badge";

interface JobsProps {
  onNavigate: (screen: string) => void;
  onOpenJob: (id: Id<"jobs">) => void;
}

export function Jobs({ onNavigate, onOpenJob }: JobsProps) {
  const [activeTab, setActiveTab] = useState<"in-progress" | "completed">("in-progress");

  const jobs = useQuery(api.jobs.listJobs, {
    statusGroup: activeTab === "completed" ? "completed" : "active",
    limit: 100,
  });

  const isLoading = jobs === undefined;

  return (
    <div className="min-h-screen bg-neutral-50 pb-20">
      <AppBar title="Jobs" />

      {/* Tabs */}
      <div className="bg-white border-b border-neutral-200">
        <div className="flex">
          <button
            type="button"
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
            type="button"
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
        {isLoading ? (
          <div className="p-8 flex justify-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#4F46E5]"></div>
          </div>
        ) : !jobs || jobs.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-[#6B7280]">
              {activeTab === "in-progress"
                ? "No jobs in progress"
                : "No completed jobs yet"}
            </p>
          </div>
        ) : (
          jobs.map((job) => (
            <button
              type="button"
              key={job._id}
              onClick={() => onOpenJob(job._id)}
              className="w-full bg-white rounded-lg p-4 border border-neutral-200 cursor-pointer active:bg-neutral-50 transition-colors text-left"
            >
              {/* Header */}
              <div className="flex items-start gap-3 mb-3">
                <Avatar src={job.counterpartyPhotoUrl ?? ""} alt={job.counterpartyName ?? "Tasker"} size="md" />
                <div className="flex-1 min-w-0">
                  <p className="text-neutral-900 mb-1">{job.counterpartyName ?? "Tasker"}</p>
                  <Badge variant="neutral">{job.categoryName}</Badge>
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
                    ? `Starts ${new Date(job.startDate).toLocaleDateString()}`
                    : `Completed ${
                        job.completedDate
                          ? new Date(job.completedDate).toLocaleDateString()
                          : ""
                      }`}
                </span>
              </div>

              {/* Notes */}
              {job.description && (
                <div className="bg-neutral-50 rounded p-3">
                  <p className="text-sm text-[#6B7280]">{job.description}</p>
                </div>
              )}
            </button>
          ))
        )}
      </div>

      <BottomNav active="jobs" onNavigate={onNavigate} />
    </div>
  );
}
