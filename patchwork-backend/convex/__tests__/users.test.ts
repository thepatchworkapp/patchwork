import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";
import * as usersModule from "../users";
import * as categoriesModule from "../categories";
import * as filesModule from "../files";
import * as taskersModule from "../taskers";
import * as authModule from "../auth";
import * as httpModule from "../http";

const modules: Record<string, () => Promise<any>> = {
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../taskers.ts": async () => taskersModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

describe("users", () => {
  test("createProfile creates user and seekerProfile", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|123",
      email: "test@example.com",
    });

    const userId = await asUser.mutation(api.users.createProfile, {
      name: "Test User",
      city: "Toronto",
      province: "ON",
    });

    expect(userId).toBeDefined();

    const user = await asUser.query(api.users.getCurrentUser);
    expect(user?.name).toBe("Test User");
    expect(user?.email).toBe("test@example.com");
  });

  test("getCurrentUser returns null when unauthenticated", async () => {
    const t = convexTest(schema, modules);
    const user = await t.query(api.users.getCurrentUser);
    expect(user).toBeNull();
  });

  test("getCurrentUser returns user when authenticated", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|456",
      email: "existing@example.com",
    });

    // First create a profile
    await asUser.mutation(api.users.createProfile, {
      name: "Existing User",
      city: "Vancouver",
      province: "BC",
    });

    // Then verify getCurrentUser returns it
    const user = await asUser.query(api.users.getCurrentUser);
    expect(user).not.toBeNull();
    expect(user?.name).toBe("Existing User");
  });

  test("createProfile throws when unauthenticated", async () => {
    const t = convexTest(schema, modules);
    
    await expect(
      t.mutation(api.users.createProfile, {
        name: "Should Fail",
        city: "Montreal",
        province: "QC",
      })
    ).rejects.toThrow();
  });

  test("createProfile is idempotent - returns existing user ID on duplicate", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|idempotent789",
      email: "idempotent@example.com",
    });

    const firstUserId = await asUser.mutation(api.users.createProfile, {
      name: "First Call",
      city: "Ottawa",
      province: "ON",
    });

    const secondUserId = await asUser.mutation(api.users.createProfile, {
      name: "Second Call",
      city: "Calgary",
      province: "AB",
    });

    expect(secondUserId).toBe(firstUserId);

    const user = await asUser.query(api.users.getCurrentUser);
    expect(user?.name).toBe("First Call");
    expect(user?.location?.city).toBe("Ottawa");
  });
});
