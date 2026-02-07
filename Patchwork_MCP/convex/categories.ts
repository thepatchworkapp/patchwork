import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

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
  { name: "Art Lessons", emoji: "🎸", group: "Tech & Professional", sortOrder: 75 },

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

  // Repair & Appliances
  { name: "Appliance Repair", emoji: "🔧", group: "Repair & Appliances", sortOrder: 100 },
  { name: "TV Mounting", emoji: "📺", group: "Repair & Appliances", sortOrder: 101 },
  { name: "Furniture Assembly", emoji: "🛠️", group: "Repair & Appliances", sortOrder: 102 },
];

export const seedCategories = mutation({
  handler: async (ctx) => {
    let inserted = 0;

    for (const cat of ALL_CATEGORIES) {
      const slug = toSlug(cat.name);
      const existing = await ctx.db
        .query("categories")
        .withIndex("by_slug", (q) => q.eq("slug", slug))
        .first();

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
    }

    return { total: ALL_CATEGORIES.length, inserted };
  },
});

export const listCategories = query({
  handler: async (ctx) => {
    return await ctx.db
      .query("categories")
      .withIndex("by_active", (q) => q.eq("isActive", true))
      .order("asc")
      .take(200);
  },
});

export const getCategoryBySlug = query({
  args: { slug: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("categories")
      .withIndex("by_slug", (q) => q.eq("slug", args.slug))
      .first();
  },
});
