export function Card({ children, onClick }: { children: React.ReactNode; onClick?: () => void }) {
  return (
    <div
      onClick={onClick}
      className={`bg-white border border-neutral-200 rounded-lg p-4 ${
        onClick ? "active:bg-neutral-50 cursor-pointer" : ""
      }`}
    >
      {children}
    </div>
  );
}
