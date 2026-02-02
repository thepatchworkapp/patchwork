import { Clock, DollarSign, MessageCircle, Calendar } from "lucide-react";
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Id } from "../../convex/_generated/dataModel";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Badge } from "../components/patchwork/Badge";
import { Card } from "../components/patchwork/Card";

interface JobDetailProps {
  jobId: Id<"jobs">;
  onBack: () => void;
  onNavigate?: (screen: string) => void;
}

export function JobDetail({ jobId, onBack, onNavigate }: JobDetailProps) {
  const job = useQuery(api.jobs.getJob, { jobId });
  const canReview = useQuery(api.reviews.canReview, { jobId });

  if (job === undefined) {
    return (
      <div className="min-h-screen bg-neutral-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#4F46E5]" />
      </div>
    );
  }

  if (job === null) {
    return (
      <div className="min-h-screen bg-neutral-50 pb-24">
        <AppBar title="Job Detail" onBack={onBack} />
        <div className="p-4 text-center text-neutral-600">Job not found</div>
      </div>
    );
  }

  const startDate = new Date(job.startDate).toLocaleDateString(undefined, {
    weekday: 'short',
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });

  const completedDate = job.completedDate 
    ? new Date(job.completedDate).toLocaleDateString(undefined, {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      })
    : null;

  const isCompleted = job.status === "completed";

  return (
    <div className="min-h-screen bg-neutral-50 pb-24">
      <AppBar title="Job Detail" onBack={onBack} />

      <div className="px-4 py-6 space-y-6">
        <Card>
          <div className="flex justify-between items-start mb-2">
            <div>
              <p className="text-neutral-500 text-sm mb-1">{job.categoryName}</p>
              <h2 className="text-xl font-semibold text-neutral-900 mb-2">
                {job.description.split('\n')[0].substring(0, 50)}
                {job.description.length > 50 ? "..." : ""}
              </h2>
            </div>
            <Badge variant={
              job.status === "completed" ? "success" :
              job.status === "in_progress" ? "primary" :
              "neutral"
            }>
              {job.status.replace("_", " ")}
            </Badge>
          </div>
        </Card>

        <div>
          <h3 className="text-neutral-900 font-medium mb-2">Description</h3>
          <p className="text-neutral-600 whitespace-pre-wrap">
            {job.notes || job.description}
          </p>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <Card>
            <div className="flex items-start gap-2">
              <Clock size={20} className="text-neutral-400 flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-neutral-500 text-sm mb-1">
                  {isCompleted ? "Completed" : "Start Date"}
                </p>
                <p className="text-neutral-900 text-sm font-medium">
                  {isCompleted ? completedDate : startDate}
                </p>
              </div>
            </div>
          </Card>

          <Card>
            <div className="flex items-start gap-2">
              <DollarSign size={20} className="text-neutral-400 flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-neutral-500 text-sm mb-1">Rate</p>
                <p className="text-neutral-900 font-medium">
                  ${(job.rate / 100).toFixed(2)}
                </p>
                <p className="text-neutral-500 text-xs capitalize">
                  {job.rateType}
                </p>
              </div>
            </div>
          </Card>

          <Card>
            <div className="flex items-start gap-2">
              <Calendar size={20} className="text-neutral-400 flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-neutral-500 text-sm mb-1">Created</p>
                <p className="text-neutral-900 text-sm">
                  {new Date(job.createdAt).toLocaleDateString()}
                </p>
              </div>
            </div>
          </Card>
          
          <Card>
             <div className="flex items-start gap-2">
              <MessageCircle size={20} className="text-neutral-400 flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-neutral-500 text-sm mb-1">Status</p>
                <p className="text-neutral-900 text-sm capitalize">
                  {job.status.replace("_", " ")}
                </p>
              </div>
            </div>
          </Card>
        </div>
      </div>

      {isCompleted && canReview && (
        <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-neutral-200 p-4">
          <div className="max-w-[390px] mx-auto">
            <Button 
              variant="primary" 
              fullWidth
              onClick={() => onNavigate?.("leave-review")}
            >
              Leave Review
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
