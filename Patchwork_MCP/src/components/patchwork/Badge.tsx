export function Badge({
  children,
  variant = "neutral"
}: {
  children: React.ReactNode;
  variant?: "neutral" | "success" | "warning" | "primary";
}) {
  const variants = {
    neutral: "bg-neutral-100 text-neutral-700",
    success: "bg-green-100 text-[#16A34A]",
    warning: "bg-orange-100 text-[#D97706]",
    primary: "bg-indigo-100 text-[#4F46E5]"
  };

  return (
    <span className={`px-2 py-1 rounded text-xs ${variants[variant]}`}>
      {children}
    </span>
  );
}
