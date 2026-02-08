/**
 * Generate unique test ID with format: e2e_{uuid.slice(0,8)}
 * @returns Test ID string
 */
export function generateTestId(): string {
  const uuid = crypto.randomUUID();
  return `e2e_${uuid.slice(0, 8)}`;
}

/**
 * Delete all test data with given prefix
 * Only deletes users and related data with @test.com email or e2e_ prefix
 * @param prefix - Test ID prefix (e.g., "e2e_abc12345")
 */
export async function cleanupTestRun(prefix: string): Promise<void> {
  const convexSiteUrl = process.env.VITE_CONVEX_SITE_URL || process.env.VITE_CONVEX_URL?.replace(".convex.cloud", ".convex.site");
  if (!convexSiteUrl) throw new Error("VITE_CONVEX_SITE_URL or VITE_CONVEX_URL must be set");

  // Construct test email pattern
  const testEmail = `${prefix}@test.com`;

  try {
    const res = await fetch(`${convexSiteUrl}/test-proxy`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "deleteByEmailPrefix", args: { prefix } }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "Cleanup failed");
    console.log(`Cleanup for ${testEmail} completed`);
  } catch (error) {
    console.error(`Failed to cleanup test data for ${testEmail}:`, error);
    throw error;
  }
}
