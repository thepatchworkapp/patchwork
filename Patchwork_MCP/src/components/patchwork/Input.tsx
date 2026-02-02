export function Input({
  type = "text",
  placeholder,
  value,
  onChange,
  label,
  error
}: {
  type?: string;
  placeholder?: string;
  value?: string;
  onChange?: (e: React.ChangeEvent<HTMLInputElement>) => void;
  label?: string;
  error?: string;
}) {
  return (
    <div className="w-full">
      {label && <label className="block mb-2 text-neutral-900">{label}</label>}
      <input
        type={type}
        placeholder={placeholder}
        value={value}
        onChange={onChange}
        className={`w-full px-4 py-3 border rounded-lg ${
          error ? "border-[#DC2626]" : "border-neutral-300"
        } focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1`}
      />
      {error && <p className="mt-1 text-[#DC2626]">{error}</p>}
    </div>
  );
}

export function Textarea({
  placeholder,
  value,
  onChange,
  label,
  rows = 4
}: {
  placeholder?: string;
  value?: string;
  onChange?: (e: React.ChangeEvent<HTMLTextAreaElement>) => void;
  label?: string;
  rows?: number;
}) {
  return (
    <div className="w-full">
      {label && <label className="block mb-2 text-neutral-900">{label}</label>}
      <textarea
        placeholder={placeholder}
        value={value}
        onChange={onChange}
        rows={rows}
        className="w-full px-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1 resize-none"
      />
    </div>
  );
}
