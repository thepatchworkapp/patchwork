import { describe, expect, it, vi } from "vitest";

import { APP_REVIEW_EMAIL, createReviewSession } from "../reviewAccess";

describe("reviewAccess", () => {
  it("createReviewSession works with an httpAction-style context", async () => {
    const runQuery = vi.fn().mockResolvedValue(true);
    const runMutation = vi
      .fn()
      .mockResolvedValueOnce({ betterAuthUserId: "better-auth-user" })
      .mockResolvedValueOnce({ appUserId: "app-user-id" });

    const result = await createReviewSession(
      {
        runQuery,
        runMutation,
      },
      APP_REVIEW_EMAIL
    );

    expect(runQuery).toHaveBeenCalledTimes(1);
    expect(runMutation).toHaveBeenCalledTimes(2);
    expect(result.email).toBe(APP_REVIEW_EMAIL);
    expect(result.appUserId).toBe("app-user-id");
    expect(typeof result.sessionToken).toBe("string");
    expect(result.sessionToken.length).toBeGreaterThan(0);
  });

  it("createReviewSession rejects disabled review access before creating sessions", async () => {
    const runQuery = vi.fn().mockResolvedValue(false);
    const runMutation = vi.fn();

    await expect(
      createReviewSession(
        {
          runQuery,
          runMutation,
        },
        APP_REVIEW_EMAIL
      )
    ).rejects.toThrow("App review access is disabled");

    expect(runQuery).toHaveBeenCalledTimes(1);
    expect(runMutation).not.toHaveBeenCalled();
  });
});
