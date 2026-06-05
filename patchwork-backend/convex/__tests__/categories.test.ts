// convex/__tests__/categories.test.ts
import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api, internal } from "../_generated/api";
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
  test("seedCategories creates all categories", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(internal.categories.seedCategories);
    
    const categories = await t.query(api.categories.listCategories);
    expect(categories.length).toBeGreaterThanOrEqual(50);
  });

  test("seedCategories is idempotent (running twice doesn't duplicate)", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(internal.categories.seedCategories);
    const firstRun = await t.query(api.categories.listCategories);

    await t.mutation(internal.categories.seedCategories);
    const secondRun = await t.query(api.categories.listCategories);
    
    expect(secondRun).toHaveLength(firstRun.length);
  });

  test("seedCategories creates idempotent category groups with alphabetized members", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(internal.categories.seedCategories);
    const firstRun = await t.query(api.categories.listCategoryGroups);

    await t.mutation(internal.categories.seedCategories);
    const secondRun = await t.query(api.categories.listCategoryGroups);

    expect(secondRun).toHaveLength(firstRun.length);

    const homeServices = secondRun.find((group) => group.slug === "home-services");
    expect(homeServices).toBeDefined();
    expect(homeServices?.name).toBe("Home Services");
    expect(homeServices?.categories.map((category) => category.slug)).toContain("plumbing");
    expect(homeServices?.categories.map((category) => category.slug)).toContain("cleaning");

    const memberNames = homeServices!.categories.map((category) => category.name);
    expect(memberNames).toEqual([...memberNames].sort((lhs, rhs) => lhs.localeCompare(rhs)));
  });

  test("listCategories returns all active categories sorted by sortOrder", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(internal.categories.seedCategories);
    
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
    
    await t.mutation(internal.categories.seedCategories);
    
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumbing",
    });
    
    expect(category).toBeDefined();
    expect(category?.name).toBe("Plumbing");
    expect(category?.slug).toBe("plumbing");
    expect(category?.emoji).toBe("🚰");
    expect(category?.group).toBe("Home Services");
  });

  test("seedCategories includes clear arts and music taxonomy entries", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(internal.categories.seedCategories);

    const expectedCategories = [
      {
        slug: "guitar-lessons",
        name: "Guitar Lessons",
        emoji: "🎸",
        group: "Tech & Professional",
      },
      {
        slug: "piano-lessons",
        name: "Piano Lessons",
        emoji: "🎹",
        group: "Tech & Professional",
      },
      {
        slug: "art-lessons",
        name: "Art Lessons",
        emoji: "🎨",
        group: "Tech & Professional",
      },
      {
        slug: "graphic-design",
        name: "Graphic Design",
        emoji: "🖼️",
        group: "Events & Creative",
      },
      {
        slug: "muralists",
        name: "Muralists",
        emoji: "🖌️",
        group: "Events & Creative",
      },
      {
        slug: "illustrators",
        name: "Illustrators",
        emoji: "✏️",
        group: "Events & Creative",
      },
    ];

    for (const expected of expectedCategories) {
      const category = await t.query(api.categories.getCategoryBySlug, {
        slug: expected.slug,
      });

      expect(category).toMatchObject(expected);
    }
  });

  test("getCategoryBySlug returns null for non-existent slug", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(internal.categories.seedCategories);
    
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "non-existent",
    });
    
    expect(category).toBeNull();
  });

  test("listCategories excludes inactive categories", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(internal.categories.seedCategories);
    const plumbing = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumbing",
    });
    expect(plumbing).toBeDefined();

    await t.run(async (ctx) => {
      await ctx.db.patch(plumbing!._id, {
        isActive: false,
      });
    });

    const categories = await t.query(api.categories.listCategories);
    expect(categories.find((category) => category.slug === "plumbing")).toBeUndefined();
  });
});
