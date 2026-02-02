export function Avatar({ src, alt, size = "md" }: { src?: string; alt: string; size?: "sm" | "md" | "lg" }) {
  const sizes = {
    sm: "size-8",
    md: "size-12",
    lg: "size-16"
  };

  return (
    <div className={`${sizes[size]} rounded-lg bg-neutral-200 overflow-hidden flex-shrink-0`}>
      {src ? (
        <img src={src} alt={alt} className="size-full object-cover" />
      ) : (
        <div className="size-full flex items-center justify-center text-neutral-600">
          {alt.charAt(0).toUpperCase()}
        </div>
      )}
    </div>
  );
}
