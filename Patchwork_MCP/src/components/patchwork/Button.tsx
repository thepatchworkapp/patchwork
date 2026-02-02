export function Button({
  variant = "primary",
  children,
  disabled = false,
  onClick,
  fullWidth = false,
  type = "button"
}: {
  variant?: "primary" | "secondary" | "ghost";
  children: React.ReactNode;
  disabled?: boolean;
  onClick?: () => void;
  fullWidth?: boolean;
  type?: "button" | "submit";
}) {
  const baseStyles = "px-4 py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed";
  
  const variants = {
    primary: "bg-[#4F46E5] text-white active:bg-[#4338CA]",
    secondary: "bg-white border border-neutral-300 text-neutral-900 active:bg-neutral-50",
    ghost: "text-[#4F46E5] active:bg-neutral-100"
  };

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`${baseStyles} ${variants[variant]} ${fullWidth ? "w-full" : ""}`}
    >
      {children}
    </button>
  );
}
