import { internalMutation, query } from "./_generated/server";
import { v } from "convex/values";
import { categoryGroupValidator, categoryValidator } from "../lib/convex/validators";
import { Id } from "./_generated/dataModel";

function toSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

type CategorySeed = {
  name: string;
  slug?: string;
  emoji: string;
  group: string;
  sortOrder: number;
};

const CATEGORY_SLUG_MIGRATIONS = new Map<string, string>([
  ["computer-genius", "it-support"],
]);

const ALL_CATEGORIES: CategorySeed[] = [
  // Beauty
  { name: "Barber", emoji: "💈", group: "Beauty", sortOrder: 1 },
  { name: "Hair Removal", emoji: "🧖", group: "Beauty", sortOrder: 2 },
  { name: "Hair Stylist", emoji: "💇", group: "Beauty", sortOrder: 3 },
  { name: "Lash Tech", emoji: "👁️", group: "Beauty", sortOrder: 4 },
  { name: "Makeup Artist", emoji: "💄", group: "Beauty", sortOrder: 5 },
  { name: "Microblading", emoji: "✒️", group: "Beauty", sortOrder: 6 },
  { name: "Nail Tech", emoji: "💅", group: "Beauty", sortOrder: 7 },
  { name: "Tattoo Artist", emoji: "🖋️", group: "Beauty", sortOrder: 8 },
  { name: "Skin Treatments", emoji: "🧴", group: "Beauty", sortOrder: 9 },

  // Child Care
  { name: "Day Care & Baby Sitters", emoji: "🧸", group: "Child Care", sortOrder: 20 },
  { name: "Tutor", emoji: "📚", group: "Child Care", sortOrder: 21 },

  // Clothing
  { name: "Clothing Stylist", emoji: "👗", group: "Clothing", sortOrder: 30 },
  { name: "Tailor", emoji: "🧵", group: "Clothing", sortOrder: 31 },

  // Design, Creative & Marketing
  { name: "Engraver", emoji: "🔖", group: "Design, Creative & Marketing", sortOrder: 40 },
  { name: "Graphic Designer", emoji: "🖼️", group: "Design, Creative & Marketing", sortOrder: 41 },
  { name: "Artist", emoji: "🎨", group: "Design, Creative & Marketing", sortOrder: 42 },
  { name: "Photographer", emoji: "📸", group: "Design, Creative & Marketing", sortOrder: 43 },
  { name: "Printer", emoji: "🖨️", group: "Design, Creative & Marketing", sortOrder: 44 },
  { name: "Social Media Consultant", emoji: "📣", group: "Design, Creative & Marketing", sortOrder: 45 },
  { name: "Videographer", emoji: "🎥", group: "Design, Creative & Marketing", sortOrder: 46 },

  // Food
  { name: "Baker", emoji: "🧁", group: "Food", sortOrder: 50 },
  { name: "Caterer", emoji: "🍽️", group: "Food", sortOrder: 51 },
  { name: "Personal Chef", emoji: "👨‍🍳", group: "Food", sortOrder: 52 },

  // Health & Wellbeing
  { name: "In-Home Care", emoji: "🏥", group: "Health & Wellbeing", sortOrder: 60 },
  { name: "Life Coach", emoji: "🧭", group: "Health & Wellbeing", sortOrder: 61 },
  { name: "Massage", emoji: "💆", group: "Health & Wellbeing", sortOrder: 62 },
  { name: "Nutritionist", emoji: "🍏", group: "Health & Wellbeing", sortOrder: 63 },
  { name: "Personal Assistant", emoji: "🗂️", group: "Health & Wellbeing", sortOrder: 64 },
  { name: "Personal Errand Runner", emoji: "🏃", group: "Health & Wellbeing", sortOrder: 65 },
  { name: "Personal Trainer", emoji: "🏋️", group: "Health & Wellbeing", sortOrder: 66 },

  // Home & Garden
  { name: "Carpenter", emoji: "🪚", group: "Home & Garden", sortOrder: 70 },
  { name: "Carpet Cleaning", emoji: "🧼", group: "Home & Garden", sortOrder: 71 },
  { name: "Exterior Painter", emoji: "🖌️", group: "Home & Garden", sortOrder: 72 },
  { name: "Florist", emoji: "💐", group: "Home & Garden", sortOrder: 73 },
  { name: "General Contractor", emoji: "🏗️", group: "Home & Garden", sortOrder: 74 },
  { name: "General Handy-man", emoji: "🔨", group: "Home & Garden", sortOrder: 75 },
  { name: "Gutter Cleaning", emoji: "🏠", group: "Home & Garden", sortOrder: 76 },
  { name: "Interior Cleaning Services", emoji: "🧹", group: "Home & Garden", sortOrder: 77 },
  { name: "Interior Designer", emoji: "🛋️", group: "Home & Garden", sortOrder: 78 },
  { name: "Interior Painter", emoji: "🎨", group: "Home & Garden", sortOrder: 79 },
  { name: "Landscaper", emoji: "🪴", group: "Home & Garden", sortOrder: 80 },
  { name: "Mortgage Broker", emoji: "🏦", group: "Home & Garden", sortOrder: 81 },
  { name: "Plumber", emoji: "🚰", group: "Home & Garden", sortOrder: 82 },
  { name: "Professional Organizer", emoji: "📦", group: "Home & Garden", sortOrder: 83 },
  { name: "Realtor", emoji: "🏘️", group: "Home & Garden", sortOrder: 84 },
  { name: "Roofing", emoji: "🏠", group: "Home & Garden", sortOrder: 85 },
  { name: "Snow Shoveling/Removal", emoji: "❄️", group: "Home & Garden", sortOrder: 86 },
  { name: "Window Cleaning", emoji: "🪟", group: "Home & Garden", sortOrder: 87 },
  { name: "Window Install", emoji: "🪟", group: "Home & Garden", sortOrder: 88 },

  // Legal
  { name: "Lawyer", emoji: "⚖️", group: "Legal", sortOrder: 90 },

  // Mechanical
  { name: "Auto Mechanic", emoji: "🚗", group: "Mechanical", sortOrder: 100 },
  { name: "Small Engine Repair", emoji: "🔧", group: "Mechanical", sortOrder: 101 },

  // Music
  { name: "Bands/Musicians", emoji: "🎵", group: "Music", sortOrder: 110 },
  { name: "DJ", emoji: "🎧", group: "Music", sortOrder: 111 },
  { name: "Guitar Lessons", emoji: "🎸", group: "Music", sortOrder: 112 },
  { name: "Piano Lessons", emoji: "🎹", group: "Music", sortOrder: 113 },

  // Pet Care
  { name: "Dog Walker", emoji: "🐕", group: "Pet Care", sortOrder: 120 },
  { name: "Pet Groomer", emoji: "✂️", group: "Pet Care", sortOrder: 121 },
  { name: "Pet Sitting", emoji: "🐾", group: "Pet Care", sortOrder: 122 },

  // Planners
  { name: "Event Planner", emoji: "🎉", group: "Planners", sortOrder: 130 },
  { name: "Travel Planner", emoji: "✈️", group: "Planners", sortOrder: 131 },
  { name: "Wedding Planner", emoji: "💍", group: "Planners", sortOrder: 132 },

  // Sports
  { name: "Baseball Instructor", emoji: "⚾", group: "Sports", sortOrder: 140 },
  { name: "Figure Skating Coach", emoji: "⛸️", group: "Sports", sortOrder: 141 },
  { name: "Golf Instructor", emoji: "⛳", group: "Sports", sortOrder: 142 },
  { name: "Hockey Instructor", emoji: "🏒", group: "Sports", sortOrder: 143 },
  { name: "Tennis Instructor", emoji: "🎾", group: "Sports", sortOrder: 144 },

  // Technical
  { name: "Architect", emoji: "📐", group: "Technical", sortOrder: 150 },
  { name: "IT Support", emoji: "💻", group: "Technical", sortOrder: 151 },
  { name: "Developers", emoji: "⌨️", group: "Technical", sortOrder: 152 },
  { name: "Electrician", emoji: "🔌", group: "Technical", sortOrder: 153 },
  { name: "Engineer", emoji: "⚙️", group: "Technical", sortOrder: 154 },
  { name: "Tax Consultant", emoji: "🧾", group: "Technical", sortOrder: 155 },
  { name: "Web Designer", emoji: "🌐", group: "Technical", sortOrder: 156 },

  // Writing & Proofreading
  { name: "Copywriter", emoji: "✍️", group: "Writing & Proofreading", sortOrder: 160 },
  { name: "Editor", emoji: "📝", group: "Writing & Proofreading", sortOrder: 161 },
  { name: "Resume Consultant", emoji: "📄", group: "Writing & Proofreading", sortOrder: 162 },
];

function categorySlug(category: { name: string; slug?: string }): string {
  return category.slug ?? toSlug(category.name);
}

async function findCategoryBySlug(ctx: any, slug: string) {
  return await ctx.db
    .query("categories")
    .withIndex("by_slug", (q: any) => q.eq("slug", slug))
    .unique();
}

async function removeMappingsForCategory(ctx: any, categoryId: Id<"categories">) {
  const mappings = await ctx.db
    .query("categoryGroupMappings")
    .withIndex("by_category", (q: any) => q.eq("categoryId", categoryId))
    .collect();

  for (const mapping of mappings) {
    await ctx.db.delete(mapping._id);
  }
}

async function moveTaskerCategoryReferences(
  ctx: any,
  fromCategoryId: Id<"categories">,
  toCategoryId: Id<"categories">,
  now: number
) {
  const taskerCategories = await ctx.db
    .query("taskerCategories")
    .withIndex("by_category", (q: any) => q.eq("categoryId", fromCategoryId))
    .collect();

  for (const taskerCategory of taskerCategories) {
    const duplicate = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q: any) =>
        q.eq("taskerProfileId", taskerCategory.taskerProfileId).eq("categoryId", toCategoryId)
      )
      .first();

    if (duplicate) {
      continue;
    }

    await ctx.db.patch(taskerCategory._id, {
      categoryId: toCategoryId,
      updatedAt: now,
    });
  }
}

async function migrateCategorySlugs(
  ctx: any,
  categoriesBySlug: Map<string, CategorySeed>,
  now: number
) {
  for (const [legacySlug, replacementSlug] of CATEGORY_SLUG_MIGRATIONS) {
    const legacyCategory = await findCategoryBySlug(ctx, legacySlug);
    if (!legacyCategory) {
      continue;
    }

    const replacementSeed = categoriesBySlug.get(replacementSlug);
    if (!replacementSeed) {
      continue;
    }

    const replacementCategory = await findCategoryBySlug(ctx, replacementSlug);
    if (!replacementCategory || replacementCategory._id === legacyCategory._id) {
      await ctx.db.patch(legacyCategory._id, {
        name: replacementSeed.name,
        slug: replacementSlug,
        emoji: replacementSeed.emoji,
        group: replacementSeed.group,
        isActive: true,
        sortOrder: replacementSeed.sortOrder,
      });
      continue;
    }

    await moveTaskerCategoryReferences(ctx, legacyCategory._id, replacementCategory._id, now);
    await removeMappingsForCategory(ctx, legacyCategory._id);
    await ctx.db.patch(legacyCategory._id, {
      name: replacementSeed.name,
      emoji: replacementSeed.emoji,
      group: replacementSeed.group,
      isActive: false,
      sortOrder: replacementSeed.sortOrder,
    });
  }
}

export const seedCategories = internalMutation({
  args: {},
  returns: v.object({
    total: v.number(),
    inserted: v.number(),
    groups: v.number(),
  }),
  handler: async (ctx) => {
    let inserted = 0;
    const now = Date.now();
    const groupByName = new Map<string, { groupId: Id<"categoryGroups">; sortOrder: number }>();
    const categoriesBySlug = new Map(ALL_CATEGORIES.map((category) => [categorySlug(category), category]));
    const activeCategorySlugs = new Set(categoriesBySlug.keys());
    const activeGroupSlugs = new Set(ALL_CATEGORIES.map((category) => toSlug(category.group)));
    const desiredMappingKeys = new Set<string>();

    await migrateCategorySlugs(ctx, categoriesBySlug, now);

    for (const cat of ALL_CATEGORIES) {
      if (groupByName.has(cat.group)) {
        continue;
      }

      const slug = toSlug(cat.group);
      const existingGroup = await ctx.db
        .query("categoryGroups")
        .withIndex("by_slug", (q) => q.eq("slug", slug))
        .unique();
      const sortOrder = cat.sortOrder;

      if (existingGroup) {
        await ctx.db.patch(existingGroup._id, {
          name: cat.group,
          sortOrder,
          isActive: true,
          updatedAt: now,
        });
        groupByName.set(cat.group, { groupId: existingGroup._id, sortOrder });
      } else {
        const groupId = await ctx.db.insert("categoryGroups", {
          name: cat.group,
          slug,
          sortOrder,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        });
        groupByName.set(cat.group, { groupId, sortOrder });
      }
    }

    for (const cat of ALL_CATEGORIES) {
      const slug = categorySlug(cat);
      const existing = await ctx.db
        .query("categories")
        .withIndex("by_slug", (q) => q.eq("slug", slug))
        .unique();

      if (existing) {
        await ctx.db.patch(existing._id, {
          name: cat.name,
          emoji: cat.emoji,
          group: cat.group,
          isActive: true,
          sortOrder: cat.sortOrder,
        });
      } else {
        await ctx.db.insert("categories", {
          name: cat.name,
          slug,
          emoji: cat.emoji,
          group: cat.group,
          isActive: true,
          sortOrder: cat.sortOrder,
        });
        inserted++;
      }

      const category = await ctx.db
        .query("categories")
        .withIndex("by_slug", (q) => q.eq("slug", slug))
        .unique();
      const group = groupByName.get(cat.group);
      if (!category || !group) {
        continue;
      }
      desiredMappingKeys.add(`${group.groupId}:${category._id}`);

      const existingMapping = await ctx.db
        .query("categoryGroupMappings")
        .withIndex("by_group_category", (q) =>
          q.eq("groupId", group.groupId).eq("categoryId", category._id)
        )
        .unique();

      if (existingMapping) {
        await ctx.db.patch(existingMapping._id, {
          sortOrder: cat.sortOrder,
          updatedAt: now,
        });
      } else {
        await ctx.db.insert("categoryGroupMappings", {
          groupId: group.groupId,
          categoryId: category._id,
          sortOrder: cat.sortOrder,
          createdAt: now,
          updatedAt: now,
        });
      }
    }

    const existingCategories = await ctx.db.query("categories").collect();
    for (const category of existingCategories) {
      if (activeCategorySlugs.has(category.slug) || !category.isActive) {
        continue;
      }
      await ctx.db.patch(category._id, { isActive: false });
    }

    const existingGroups = await ctx.db.query("categoryGroups").collect();
    for (const group of existingGroups) {
      if (activeGroupSlugs.has(group.slug) || !group.isActive) {
        continue;
      }
      await ctx.db.patch(group._id, { isActive: false, updatedAt: now });
    }

    const existingMappings = await ctx.db.query("categoryGroupMappings").collect();
    for (const mapping of existingMappings) {
      if (desiredMappingKeys.has(`${mapping.groupId}:${mapping.categoryId}`)) {
        continue;
      }
      await ctx.db.delete(mapping._id);
    }

    return { total: ALL_CATEGORIES.length, inserted, groups: groupByName.size };
  },
});

export const listCategories = query({
  args: {},
  returns: v.array(categoryValidator),
  handler: async (ctx) => {
    await ctx.auth.getUserIdentity();

    const categories = await ctx.db
      .query("categories")
      .withIndex("by_active", (q) => q.eq("isActive", true))
      .collect();

    categories.sort((lhs, rhs) => {
      const lhsSortOrder = lhs.sortOrder ?? Number.MAX_SAFE_INTEGER;
      const rhsSortOrder = rhs.sortOrder ?? Number.MAX_SAFE_INTEGER;
      if (lhsSortOrder !== rhsSortOrder) {
        return lhsSortOrder - rhsSortOrder;
      }
      return lhs.name.localeCompare(rhs.name, undefined, { sensitivity: "base" });
    });

    return categories.map((category) => ({
      _id: category._id,
      name: category.name,
      slug: category.slug,
      icon: category.icon,
      emoji: category.emoji,
      group: category.group,
      description: category.description,
      isActive: category.isActive,
      sortOrder: category.sortOrder,
    }));
  },
});

export const listCategoryGroups = query({
  args: {},
  returns: v.array(categoryGroupValidator),
  handler: async (ctx) => {
    await ctx.auth.getUserIdentity();

    const groups = await ctx.db
      .query("categoryGroups")
      .withIndex("by_active", (q) => q.eq("isActive", true))
      .collect();

    groups.sort((lhs, rhs) => {
      if (lhs.sortOrder !== rhs.sortOrder) {
        return lhs.sortOrder - rhs.sortOrder;
      }
      return lhs.name.localeCompare(rhs.name);
    });

    const results = [];
    for (const group of groups) {
      const mappings = await ctx.db
        .query("categoryGroupMappings")
        .withIndex("by_group", (q) => q.eq("groupId", group._id))
        .collect();

      const categories = [];
      for (const mapping of mappings) {
        const category = await ctx.db.get(mapping.categoryId);
        if (!category?.isActive) {
          continue;
        }
        categories.push({
          _id: category._id,
          name: category.name,
          slug: category.slug,
          icon: category.icon,
          emoji: category.emoji,
          group: category.group,
          description: category.description,
          isActive: category.isActive,
          sortOrder: category.sortOrder,
        });
      }

      categories.sort((lhs, rhs) =>
        lhs.name.localeCompare(rhs.name, undefined, { sensitivity: "base" })
      );

      if (categories.length === 0) {
        continue;
      }

      results.push({
        _id: group._id,
        name: group.name,
        slug: group.slug,
        description: group.description,
        sortOrder: group.sortOrder,
        categories,
      });
    }

    return results;
  },
});

export const getCategoryBySlug = query({
  args: { slug: v.string() },
  returns: v.union(categoryValidator, v.null()),
  handler: async (ctx, args) => {
    await ctx.auth.getUserIdentity();

    const category = await ctx.db
      .query("categories")
      .withIndex("by_slug", (q) => q.eq("slug", args.slug))
      .unique();

    if (!category?.isActive) {
      return null;
    }

    return {
      _id: category._id,
      name: category.name,
      slug: category.slug,
      icon: category.icon,
      emoji: category.emoji,
      group: category.group,
      description: category.description,
      isActive: category.isActive,
      sortOrder: category.sortOrder,
    };
  },
});
