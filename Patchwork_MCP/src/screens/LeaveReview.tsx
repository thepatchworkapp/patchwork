import { useState } from "react";
import { Star, Camera } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { Avatar } from "../components/patchwork/Avatar";
import { Textarea } from "../components/patchwork/Input";
import { Button } from "../components/patchwork/Button";

export function LeaveReview({ onBack, onSubmit }: { onBack: () => void; onSubmit: () => void }) {
  const [rating, setRating] = useState(0);
  const [review, setReview] = useState("");

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="Leave a Review" onBack={onBack} />

      <div className="flex-1 px-4 pt-6">
        <div className="bg-neutral-50 rounded-lg p-4 mb-6">
          <div className="flex items-center gap-3 mb-3">
            <Avatar src="" alt="Alex Chen" size="md" />
            <div>
              <p className="text-neutral-900">Alex Chen</p>
              <p className="text-[#6B7280] text-sm">Plumbing</p>
            </div>
          </div>
          <div className="flex items-center gap-2 text-sm">
            <span className="text-[#16A34A]">✓</span>
            <span className="text-[#6B7280]">Job completed Nov 2, 2024</span>
          </div>
        </div>

        <div className="mb-6">
          <label className="block mb-3 text-neutral-900">How was your experience?</label>
          <div className="flex justify-center gap-2 mb-2">
            {[1, 2, 3, 4, 5].map((star) => (
              <button
                key={star}
                onClick={() => setRating(star)}
                className="transition-transform active:scale-90"
              >
                <Star
                  size={40}
                  className={star <= rating ? "fill-yellow-400 text-yellow-400" : "text-neutral-300"}
                />
              </button>
            ))}
          </div>
          <p className="text-center text-[#6B7280] text-sm">
            {rating === 0 && "Tap to rate"}
            {rating === 1 && "Poor"}
            {rating === 2 && "Fair"}
            {rating === 3 && "Good"}
            {rating === 4 && "Very good"}
            {rating === 5 && "Excellent"}
          </p>
        </div>

        <Textarea
          label="Tell others about your experience"
          placeholder="Share details about the quality of work, professionalism, timeliness, communication, etc."
          value={review}
          onChange={(e) => setReview(e.target.value)}
          rows={6}
        />

        <div className="mt-4 mb-6">
          <label className="block mb-3 text-neutral-900">Add photos (optional)</label>
          <button className="border-2 border-dashed border-neutral-300 rounded-lg p-6 w-full flex flex-col items-center gap-2 text-[#6B7280]">
            <Camera size={32} />
            <span>Upload photos of the completed work</span>
          </button>
        </div>

        <div className="bg-indigo-50 rounded-lg p-4">
          <p className="text-[#4F46E5] mb-2">Review policy</p>
          <p className="text-[#6B7280] text-sm">
            Only verified job participants can leave reviews. Your review helps maintain trust and quality in the Patchwork community. All reviews are public and cannot be deleted.
          </p>
        </div>
      </div>

      <div className="p-4 border-t border-neutral-200">
        <Button
          variant="primary"
          fullWidth
          onClick={onSubmit}
          disabled={rating === 0 || !review.trim()}
        >
          Submit Review
        </Button>
      </div>
    </div>
  );
}
