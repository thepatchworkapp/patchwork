import { ArrowLeft, Menu } from "lucide-react";

export function AppBar({
  title,
  onBack,
  onMenu,
  action
}: {
  title?: string;
  onBack?: () => void;
  onMenu?: () => void;
  action?: React.ReactNode;
}) {
  return (
    <div className="bg-white border-b border-neutral-200 px-4 py-3 flex items-center justify-between">
      <div className="flex items-center gap-3">
        {onBack && (
          <button onClick={onBack} className="p-1 -ml-1">
            <ArrowLeft size={24} className="text-neutral-900" />
          </button>
        )}
        {title && <h1 className="text-neutral-900">{title}</h1>}
      </div>
      {action && <div>{action}</div>}
      {onMenu && (
        <button onClick={onMenu} className="p-1 -mr-1">
          <Menu size={24} className="text-neutral-900" />
        </button>
      )}
    </div>
  );
}
