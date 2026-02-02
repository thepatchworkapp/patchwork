// convex/__tests__/categories.test.ts
import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";
import * as categoriesModule from "../categories";
import * as usersModule from "../users";
import * as filesModule from "../files";
import * as authModule from "../auth";
import * as httpModule from "../http";

const modules: Record<string, () => Promise<any>> = {
  "../categories.ts": async () => categoriesModule,
  "../users.ts": async () => usersModule,
  "../files.ts": async () => filesModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

describe("categories", () => {
  test("seedCategories creates 15 categories", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(api.categories.seedCategories);
    
    const categories = await t.query(api.categories.listCategories);
    expect(categories).toHaveLength(15);
  });

  test("seedCategories is idempotent (running twice doesn't duplicate)", async () => {
    const t = convexTest(schema, modules);
    
    // Run seed twice
    await t.mutation(api.categories.seedCategories);
    await t.mutation(api.categories.seedCategories);
    
    const categories = await t.query(api.categories.listCategories);
    expect(categories).toHaveLength(15);
  });

  test("listCategories returns all active categories sorted by sortOrder", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(api.categories.seedCategories);
    
    const categories = await t.query(api.categories.listCategories);
    
    // Check all are active
    expect(categories.every((c) => c.isActive)).toBe(true);
    
    // Check sorted by sortOrder
    for (let i = 0; i < categories.length - 1; i++) {
      expect(categories[i].sortOrder).toBeLessThanOrEqual(
        categories[i + 1].sortOrder
      );
    }
  });

  test("getCategoryBySlug returns single category by slug", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(api.categories.seedCategories);
    
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumbing",
    });
    
    expect(category).toBeDefined();
    expect(category?.name).toBe("Plumbing");
    expect(category?.slug).toBe("plumbing");
    expect(category?.icon).toBe("wrench");
    expect(category?.sortOrder).toBe(1);
  });

  test("getCategoryBySlug returns null for non-existent slug", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(api.categories.seedCategories);
    
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "non-existent",
    });
    
    expect(category).toBeNull();
  });
});
