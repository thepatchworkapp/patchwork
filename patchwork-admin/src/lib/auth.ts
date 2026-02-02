// Admin dashboard OTP authentication
// Hardcoded admin email: daveald@gmail.com
// OTP stored in Convex otps table, logged to console

const ADMIN_EMAIL = "daveald@gmail.com";

/**
 * Generate a 6-digit OTP code
 */
export function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Send OTP to admin email
 * - Validates email is admin email
 * - Generates 6-digit OTP
 * - Stores in Convex otps table
 * - Logs to console (no email sending)
 */
export async function sendOTP(email: string): Promise<void> {
  // Validate email
  if (email !== ADMIN_EMAIL) {
    throw new Error("Invalid email. Only daveald@gmail.com is authorized.");
  }

  // Generate OTP
  const otp = generateOTP();

  // Store in Convex otps table
  try {
    const response = await fetch("/api/admin/send-otp", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, otp }),
    });

    if (!response.ok) {
      throw new Error("Failed to store OTP");
    }

    // Log to console for testing
    console.log(`🔐 OTP for ${email}: ${otp}`);
  } catch (error) {
    console.error("Error sending OTP:", error);
    throw error;
  }
}

/**
 * Verify OTP against stored value in Convex
 * - Checks email is admin email
 * - Verifies OTP matches stored value
 * - Returns true if valid, throws if invalid
 */
export async function verifyOTP(email: string, otp: string): Promise<boolean> {
  // Validate email
  if (email !== ADMIN_EMAIL) {
    throw new Error("Invalid email. Only daveald@gmail.com is authorized.");
  }

  // Verify OTP with Convex
  try {
    const response = await fetch("/api/admin/verify-otp", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, otp }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || "Invalid OTP");
    }

    return true;
  } catch (error) {
    console.error("Error verifying OTP:", error);
    throw error;
  }
}

/**
 * Get the hardcoded admin email
 */
export function getAdminEmail(): string {
  return ADMIN_EMAIL;
}
