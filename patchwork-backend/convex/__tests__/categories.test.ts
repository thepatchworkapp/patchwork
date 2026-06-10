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

const expectedCategoryGroups = [
  {
    slug: "beauty",
    name: "Beauty",
    categorySlugs: [
      "barber",
      "hair-removal",
      "hair-stylist",
      "lash-tech",
      "makeup-artist",
      "microblading",
      "nail-tech",
      "skin-treatments",
      "tattoo-artist",
    ],
  },
  {
    slug: "child-care",
    name: "Child Care",
    categorySlugs: ["day-care-baby-sitters", "tutor"],
  },
  {
    slug: "clothing",
    name: "Clothing",
    categorySlugs: ["clothing-stylist", "tailor"],
  },
  {
    slug: "design-creative-marketing",
    name: "Design, Creative & Marketing",
    categorySlugs: [
      "artist",
      "engraver",
      "graphic-designer",
      "photographer",
      "printer",
      "social-media-consultant",
      "videographer",
    ],
  },
  {
    slug: "food",
    name: "Food",
    categorySlugs: ["baker", "caterer", "personal-chef"],
  },
  {
    slug: "health-wellbeing",
    name: "Health & Wellbeing",
    categorySlugs: [
      "in-home-care",
      "life-coach",
      "massage",
      "nutritionist",
      "personal-assistant",
      "personal-errand-runner",
      "personal-trainer",
    ],
  },
  {
    slug: "home-garden",
    name: "Home & Garden",
    categorySlugs: [
      "carpenter",
      "carpet-cleaning",
      "exterior-painter",
      "florist",
      "general-contractor",
      "general-handy-man",
      "gutter-cleaning",
      "interior-cleaning-services",
      "interior-designer",
      "interior-painter",
      "landscaper",
      "mortgage-broker",
      "plumber",
      "professional-organizer",
      "realtor",
      "roofing",
      "snow-shoveling-removal",
      "window-cleaning",
      "window-install",
    ],
  },
  {
    slug: "legal",
    name: "Legal",
    categorySlugs: ["lawyer"],
  },
  {
    slug: "mechanical",
    name: "Mechanical",
    categorySlugs: ["auto-mechanic", "small-engine-repair"],
  },
  {
    slug: "music",
    name: "Music",
    categorySlugs: ["bands-musicians", "dj", "guitar-lessons", "piano-lessons"],
  },
  {
    slug: "pet-care",
    name: "Pet Care",
    categorySlugs: ["dog-walker", "pet-groomer", "pet-sitting"],
  },
  {
    slug: "planners",
    name: "Planners",
    categorySlugs: ["event-planner", "travel-planner", "wedding-planner"],
  },
  {
    slug: "sports",
    name: "Sports",
    categorySlugs: [
      "baseball-instructor",
      "figure-skating-coach",
      "golf-instructor",
      "hockey-instructor",
      "tennis-instructor",
    ],
  },
  {
    slug: "technical",
    name: "Technical",
    categorySlugs: [
      "architect",
      "computer-genius",
      "developers",
      "electrician",
      "engineer",
      "tax-consultant",
      "web-designer",
    ],
  },
  {
    slug: "writing-proofreading",
    name: "Writing & Proofreading",
    categorySlugs: ["copywriter", "editor", "resume-consultant"],
  },
];

describe("categories", () => {
  test("seedCategories creates all categories", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(internal.categories.seedCategories);
    
    const categories = await t.query(api.categories.listCategories);
    expect(categories).toHaveLength(77);
    expect(new Set(categories.map((category) => category.slug)).size).toBe(77);
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

    expect(secondRun).toHaveLength(expectedCategoryGroups.length);

    const homeGarden = secondRun.find((group) => group.slug === "home-garden");
    expect(homeGarden).toBeDefined();
    expect(homeGarden?.name).toBe("Home & Garden");
    expect(homeGarden?.categories.map((category) => category.slug)).toContain("plumber");
    expect(homeGarden?.categories.map((category) => category.slug)).toContain("interior-cleaning-services");

    const memberNames = homeGarden!.categories.map((category) => category.name);
    expect(memberNames).toEqual([...memberNames].sort((lhs, rhs) => lhs.localeCompare(rhs)));
  });

  test("seedCategories maps the intended taxonomy exactly", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(internal.categories.seedCategories);

    const groups = await t.query(api.categories.listCategoryGroups);
    expect(groups.map((group) => group.slug)).toEqual(expectedCategoryGroups.map((group) => group.slug));

    for (const expectedGroup of expectedCategoryGroups) {
      const group = groups.find((candidate) => candidate.slug === expectedGroup.slug);
      expect(group?.name).toBe(expectedGroup.name);
      expect(group?.categories.map((category) => category.slug).sort()).toEqual(
        [...expectedGroup.categorySlugs].sort()
      );
    }
  });

  test("seedCategories displays IT Support while preserving the legacy technical slug", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(internal.categories.seedCategories);

    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "computer-genius",
    });

    expect(category).toMatchObject({
      name: "IT Support",
      slug: "computer-genius",
      emoji: "💻",
      group: "Technical",
    });
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
      slug: "plumber",
    });
    
    expect(category).toBeDefined();
    expect(category?.name).toBe("Plumber");
    expect(category?.slug).toBe("plumber");
    expect(category?.emoji).toBe("🚰");
    expect(category?.group).toBe("Home & Garden");
  });

  test("seedCategories includes clear arts and music taxonomy entries", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(internal.categories.seedCategories);

    const expectedCategories = [
      {
        slug: "guitar-lessons",
        name: "Guitar Lessons",
        emoji: "🎸",
        group: "Music",
      },
      {
        slug: "piano-lessons",
        name: "Piano Lessons",
        emoji: "🎹",
        group: "Music",
      },
      {
        slug: "artist",
        name: "Artist",
        emoji: "🎨",
        group: "Design, Creative & Marketing",
      },
      {
        slug: "graphic-designer",
        name: "Graphic Designer",
        emoji: "🖼️",
        group: "Design, Creative & Marketing",
      },
      {
        slug: "photographer",
        name: "Photographer",
        emoji: "📸",
        group: "Design, Creative & Marketing",
      },
      {
        slug: "videographer",
        name: "Videographer",
        emoji: "🎥",
        group: "Design, Creative & Marketing",
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
    const plumber = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumber",
    });
    expect(plumber).toBeDefined();

    await t.run(async (ctx) => {
      await ctx.db.patch(plumber!._id, {
        isActive: false,
      });
    });

    const categories = await t.query(api.categories.listCategories);
    expect(categories.find((category) => category.slug === "plumber")).toBeUndefined();
  });

  test("seedCategories deactivates retired categories and removes stale mappings", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(internal.categories.seedCategories);
    const staleIds = await t.run(async (ctx) => {
      const groupId = await ctx.db.insert("categoryGroups", {
        name: "Retired Group",
        slug: "retired-group",
        sortOrder: 999,
        isActive: true,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });
      const categoryId = await ctx.db.insert("categories", {
        name: "Retired Category",
        slug: "retired-category",
        group: "Retired Group",
        isActive: true,
        sortOrder: 999,
      });
      const mappingId = await ctx.db.insert("categoryGroupMappings", {
        groupId,
        categoryId,
        sortOrder: 999,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });
      return { groupId, categoryId, mappingId };
    });

    await t.mutation(internal.categories.seedCategories);

    const staleCategory = await t.query(api.categories.getCategoryBySlug, {
      slug: "retired-category",
    });
    expect(staleCategory).toBeNull();

    const groups = await t.query(api.categories.listCategoryGroups);
    expect(groups.find((group) => group.slug === "retired-group")).toBeUndefined();

    await t.run(async (ctx) => {
      expect(await ctx.db.get(staleIds.mappingId)).toBeNull();
    });
  });
});
