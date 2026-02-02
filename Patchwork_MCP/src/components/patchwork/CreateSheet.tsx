import { Briefcase, PlusCircle, Camera, Clock } from "lucide-react";
import { Button } from "./Button";

export function CreateSheet({ onClose, onPostJob, onListService, hasTaskerProfile }: {
  onClose: () => void;
  onPostJob: () => void;
  onListService: () => void;
  hasTaskerProfile: boolean;
}) {
  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-end" onClick={onClose}>
      <div
        className="bg-white rounded-t-2xl w-full max-w-[390px] mx-auto p-6 pb-8"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="w-12 h-1 bg-neutral-300 rounded-full mx-auto mb-6" />
        
        <h2 className="text-neutral-900 mb-6 text-center">Create</h2>

        <div className="space-y-3 mb-6">
          <button
            onClick={onPostJob}
            className="w-full p-4 border border-neutral-200 rounded-lg flex items-center gap-4 active:bg-neutral-50 text-left"
          >
            <div className="size-12 rounded-lg bg-indigo-100 flex items-center justify-center flex-shrink-0">
              <PlusCircle size={24} className="text-[#4F46E5]" />
            </div>
            <div>
              <p className="text-neutral-900 mb-1">Post a Job</p>
              <p className="text-[#6B7280] text-sm">Find providers for a task</p>
            </div>
          </button>

          <button
            onClick={onListService}
            className="w-full p-4 border border-neutral-200 rounded-lg flex items-center gap-4 active:bg-neutral-50 text-left"
          >
            <div className="size-12 rounded-lg bg-indigo-100 flex items-center justify-center flex-shrink-0">
              <Briefcase size={24} className="text-[#4F46E5]" />
            </div>
            <div>
              <p className="text-neutral-900 mb-1">List a Service</p>
              <p className="text-[#6B7280] text-sm">
                {hasTaskerProfile ? "Update your offerings" : "Start earning on Patchwork"}
              </p>
            </div>
          </button>
        </div>

        <div className="flex gap-3 text-[#4F46E5] text-sm">
          <button className="flex items-center gap-2 px-3 py-2">
            <Camera size={16} />
            <span>Scan ID</span>
          </button>
          <button className="flex items-center gap-2 px-3 py-2">
            <Clock size={16} />
            <span>Edit Availability</span>
          </button>
        </div>
      </div>
    </div>
  );
}
