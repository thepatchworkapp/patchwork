import { useState } from "react";
import { AppBar } from "../components/patchwork/AppBar";
import { Button } from "../components/patchwork/Button";
import { Textarea } from "../components/patchwork/Input";
import { Chip } from "../components/patchwork/Chip";

export function RequestStep1({ onBack, onNext }: { onBack: () => void; onNext: () => void }) {
  const [category, setCategory] = useState("Plumbing");
  const [description, setDescription] = useState("");

  const categories = ["Plumbing", "Electrical", "Handyman", "Cleaning", "Moving", "Painting"];

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <AppBar title="New Request" onBack={onBack} />

      <div className="flex-1 px-4 pt-6">
        <div className="mb-6">
          <div className="flex items-center gap-2 mb-6">
            <div className="size-8 rounded-full bg-[#4F46E5] text-white flex items-center justify-center">1</div>
            <div className="flex-1 h-1 bg-neutral-200" />
            <div className="size-8 rounded-full bg-neutral-200 text-[#6B7280] flex items-center justify-center">2</div>
            <div className="flex-1 h-1 bg-neutral-200" />
            <div className="size-8 rounded-full bg-neutral-200 text-[#6B7280] flex items-center justify-center">3</div>
            <div className="flex-1 h-1 bg-neutral-200" />
            <div className="size-8 rounded-full bg-neutral-200 text-[#6B7280] flex items-center justify-center">4</div>
          </div>
        </div>

        <h2 className="text-neutral-900 mb-2">What do you need?</h2>
        <p className="text-[#6B7280] mb-6">Select a category and describe the task</p>

        <div className="mb-6">
          <label className="block mb-3 text-neutral-900">Category</label>
          <div className="flex flex-wrap gap-2">
            {categories.map((cat) => (
              <Chip
                key={cat}
                label={cat}
                active={category === cat}
                onClick={() => setCategory(cat)}
              />
            ))}
          </div>
        </div>

        <Textarea
          label="Describe your task"
          placeholder="E.g., Kitchen sink is leaking under the counter. Water drips constantly even when taps are off. Need someone to diagnose and fix ASAP."
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={6}
        />

        <p className="text-[#6B7280] text-sm mt-2">
          Be specific about the problem, location in your home, and any relevant details. This helps Taskers provide accurate quotes.
        </p>
      </div>

      <div className="p-4 border-t border-neutral-200">
        <Button variant="primary" fullWidth onClick={onNext} disabled={!description.trim()}>
          Continue
        </Button>
      </div>
    </div>
  );
}
