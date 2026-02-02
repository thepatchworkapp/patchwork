export function Chip({
  label,
  active = false,
  onClick
}: {
  label: string;
  active?: boolean;
  onClick?: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={`px-4 py-2 rounded-full border transition-colors ${
        active
          ? "bg-[#4F46E5] text-white border-[#4F46E5]"
          : "bg-white text-neutral-700 border-neutral-300 active:bg-neutral-50"
      }`}
    >
      {label}
    </button>
  );
}
