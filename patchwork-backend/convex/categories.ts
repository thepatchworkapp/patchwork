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

const ALL_CATEGORIES: {
  name: string;
  emoji: string;
  group: string;
  sortOrder: number;
}[] = [
  // Beauty
  { name: "Makeup Artist", emoji: "💄", group: "Beauty", sortOrder: 1 },
  { name: "Hair Stylist", emoji: "💇", group: "Beauty", sortOrder: 2 },
  { name: "Lash Tech", emoji: "👁️", group: "Beauty", sortOrder: 3 },
  { name: "Nail Tech", emoji: "💅", group: "Beauty", sortOrder: 4 },
  { name: "Hair Removal", emoji: "🧖", group: "Beauty", sortOrder: 5 },

  // Home & Garden
  { name: "Property Maintenance", emoji: "🔧", group: "Home & Garden", sortOrder: 10 },
  { name: "Interior Painter", emoji: "🎨", group: "Home & Garden", sortOrder: 11 },
  { name: "Exterior Painter", emoji: "🖌️", group: "Home & Garden", sortOrder: 12 },
  { name: "Window Cleaner", emoji: "🚪", group: "Home & Garden", sortOrder: 13 },
  { name: "Gutter Cleaning", emoji: "🏠", group: "Home & Garden", sortOrder: 14 },
  { name: "Gardening", emoji: "🌳", group: "Home & Garden", sortOrder: 15 },
  { name: "Landscaping", emoji: "🪴", group: "Home & Garden", sortOrder: 16 },
  { name: "Lawn Care", emoji: "🌿", group: "Home & Garden", sortOrder: 17 },

  // Health & Wellbeing
  { name: "Massage Therapist", emoji: "💆", group: "Health & Wellbeing", sortOrder: 20 },
  { name: "Nutritionist", emoji: "🍏", group: "Health & Wellbeing", sortOrder: 21 },
  { name: "Care Giver", emoji: "👵", group: "Health & Wellbeing", sortOrder: 22 },
  { name: "Personal Trainer", emoji: "🏋️", group: "Health & Wellbeing", sortOrder: 23 },
  { name: "Errand Runner", emoji: "🏃", group: "Health & Wellbeing", sortOrder: 24 },

  // Pet Care
  { name: "Dog Walking", emoji: "🐕", group: "Pet Care", sortOrder: 30 },
  { name: "Pet Sitting", emoji: "🐾", group: "Pet Care", sortOrder: 31 },
  { name: "Pet Grooming", emoji: "✂️", group: "Pet Care", sortOrder: 32 },
  { name: "Pet Training", emoji: "🐕‍🦺", group: "Pet Care", sortOrder: 33 },

  // Home Services
  { name: "Electrical", emoji: "🔌", group: "Home Services", sortOrder: 40 },
  { name: "Plumbing", emoji: "🚰", group: "Home Services", sortOrder: 41 },
  { name: "Handyman", emoji: "🔨", group: "Home Services", sortOrder: 42 },
  { name: "HVAC", emoji: "❄️", group: "Home Services", sortOrder: 43 },
  { name: "Carpentry", emoji: "🏗️", group: "Home Services", sortOrder: 44 },
  { name: "Roofing", emoji: "🏠", group: "Home Services", sortOrder: 45 },
  { name: "Flooring", emoji: "🪟", group: "Home Services", sortOrder: 46 },
  { name: "Welding", emoji: "⚡", group: "Home Services", sortOrder: 47 },
  { name: "Cleaning", emoji: "🧹", group: "Home Services", sortOrder: 48 },
  { name: "Pest Control", emoji: "🐜", group: "Home Services", sortOrder: 49 },
  { name: "Locksmith", emoji: "🔑", group: "Home Services", sortOrder: 50 },
  { name: "Painting", emoji: "🎨", group: "Home Services", sortOrder: 51 },
  { name: "House Cleaning", emoji: "🏡", group: "Home Services", sortOrder: 52 },

  // Moving & Delivery
  { name: "Moving", emoji: "📦", group: "Moving & Delivery", sortOrder: 60 },
  { name: "Delivery", emoji: "🚚", group: "Moving & Delivery", sortOrder: 61 },
  { name: "Courier", emoji: "📮", group: "Moving & Delivery", sortOrder: 62 },

  // Tech & Professional
  { name: "IT Support", emoji: "💻", group: "Tech & Professional", sortOrder: 70 },
  { name: "Phone Repair", emoji: "📱", group: "Tech & Professional", sortOrder: 71 },
  { name: "Computer Repair", emoji: "🖥️", group: "Tech & Professional", sortOrder: 72 },
  { name: "Tutoring", emoji: "📚", group: "Tech & Professional", sortOrder: 73 },
  { name: "Music Lessons", emoji: "🎓", group: "Tech & Professional", sortOrder: 74 },
  { name: "Guitar Lessons", emoji: "🎸", group: "Tech & Professional", sortOrder: 75 },
  { name: "Piano Lessons", emoji: "🎹", group: "Tech & Professional", sortOrder: 76 },
  { name: "Art Lessons", emoji: "🎨", group: "Tech & Professional", sortOrder: 77 },

  // Automotive
  { name: "Auto Repair", emoji: "🚗", group: "Automotive", sortOrder: 80 },
  { name: "Car Detailing", emoji: "🚙", group: "Automotive", sortOrder: 81 },
  { name: "Oil Change", emoji: "🔧", group: "Automotive", sortOrder: 82 },
  { name: "Car Wash", emoji: "🚘", group: "Automotive", sortOrder: 83 },

  // Events & Creative
  { name: "Photography", emoji: "📸", group: "Events & Creative", sortOrder: 90 },
  { name: "Videography", emoji: "🎥", group: "Events & Creative", sortOrder: 91 },
  { name: "Event Planning", emoji: "🎉", group: "Events & Creative", sortOrder: 92 },
  { name: "Catering", emoji: "🍽️", group: "Events & Creative", sortOrder: 93 },
  { name: "DJ Services", emoji: "🎤", group: "Events & Creative", sortOrder: 94 },
  { name: "Entertainment", emoji: "🎭", group: "Events & Creative", sortOrder: 95 },
  { name: "Graphic Design", emoji: "🖼️", group: "Events & Creative", sortOrder: 96 },
  { name: "Muralists", emoji: "🖌️", group: "Events & Creative", sortOrder: 97 },
  { name: "Illustrators", emoji: "✏️", group: "Events & Creative", sortOrder: 98 },

  // Repair & Appliances
  { name: "Appliance Repair", emoji: "🔧", group: "Repair & Appliances", sortOrder: 100 },
  { name: "TV Mounting", emoji: "📺", group: "Repair & Appliances", sortOrder: 101 },
  { name: "Furniture Assembly", emoji: "🛠️", group: "Repair & Appliances", sortOrder: 102 },
];

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
      const slug = toSlug(cat.name);
      const existing = await ctx.db
        .query("categories")
        .withIndex("by_slug", (q) => q.eq("slug", slug))
        .unique();

      if (existing) {
        await ctx.db.patch(existing._id, {
          emoji: cat.emoji,
          group: cat.group,
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
      .order("asc")
      .take(200);

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

    if (!category) {
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
