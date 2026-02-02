const ADMIN_EMAIL = "daveald@gmail.com";

export function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export async function sendOTP(email: string): Promise<void> {
  if (email !== ADMIN_EMAIL) {
    throw new Error("Invalid email. Only daveald@gmail.com is authorized.");
  }

  const otp = generateOTP();

  const response = await fetch("/api/admin/send-otp", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, otp }),
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(errorData.error || "Failed to store OTP");
  }

  console.log(`🔐 OTP for ${email}: ${otp}`);
}

export async function verifyOTP(email: string, otp: string): Promise<boolean> {
  if (email !== ADMIN_EMAIL) {
    throw new Error("Invalid email. Only daveald@gmail.com is authorized.");
  }

  const response = await fetch("/api/admin/verify-otp", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, otp }),
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(errorData.error || "Invalid OTP");
  }

  return true;
}

export function getAdminEmail(): string {
  return ADMIN_EMAIL;
}
