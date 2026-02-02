import { ConvexClient } from "convex/browser";
import { api } from "../../../convex/_generated/api";

/**
 * Initialize Convex client for testing
 */
function getConvexClient(): ConvexClient {
  const convexUrl = process.env.VITE_CONVEX_URL;
  if (!convexUrl) {
    throw new Error("VITE_CONVEX_URL environment variable is not set");
  }
  return new ConvexClient(convexUrl);
}

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
  const client = getConvexClient();

  // Construct test email pattern
  const testEmail = `${prefix}@test.com`;

  // Call cleanup mutation (to be implemented in convex/testing.ts)
  // For now, this is a placeholder that documents the cleanup pattern
  // The actual implementation will delete:
  // - Users with matching email
  // - Conversations involving those users
  // - Messages in those conversations
  // - OTP records for those emails

  try {
    // This would call a cleanup mutation once implemented
    // await client.mutation(api.testing.cleanupTestData, { email: testEmail });
    console.log(`Cleanup for ${testEmail} would be called here`);
  } catch (error) {
    console.error(`Failed to cleanup test data for ${testEmail}:`, error);
    throw error;
  }
}
