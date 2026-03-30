import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";
import * as feedbackModule from "../feedback";
import * as usersModule from "../users";
import * as authModule from "../auth";

const modules: Record<string, () => Promise<any>> = {
  "../feedback.ts": async () => feedbackModule,
  "../users.ts": async () => usersModule,
  "../auth.ts": async () => authModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

describe("feedback", () => {
  test("submit stores authenticated feedback with timestamp and user", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|feedback1",
      email: "feedback@example.com",
    });

    const userId = await asUser.mutation(api.users.createProfile, {
      name: "Feedback User",
      city: "Toronto",
      province: "ON",
    });

    const feedbackId = await asUser.mutation(api.feedback.submit, {
      message: "The new layout is much easier to use.",
    });

    expect(feedbackId).toBeDefined();

    const stored = await t.run(async (ctx) => ctx.db.get(feedbackId));
    expect(stored).not.toBeNull();
    expect(stored?.userId).toBe(userId);
    expect(stored?.message).toBe("The new layout is much easier to use.");
    expect(typeof stored?.createdAt).toBe("number");
    expect(typeof stored?.updatedAt).toBe("number");
  });

  test("submit rejects anonymous feedback", async () => {
    const t = convexTest(schema, modules);

    await expect(
      t.mutation(api.feedback.submit, {
        message: "Anonymous feedback should not work.",
      })
    ).rejects.toThrow("Unauthorized");
  });
});
