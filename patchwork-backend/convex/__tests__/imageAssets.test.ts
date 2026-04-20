import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "../_generated/api";
import schema from "../schema";
import * as authModule from "../auth";
import * as categoriesModule from "../categories";
import * as filesModule from "../files";
import * as httpModule from "../http";
import * as taskersModule from "../taskers";
import * as usersModule from "../users";

const modules: Record<string, () => Promise<any>> = {
  "../users.ts": async () => usersModule,
  "../taskers.ts": async () => taskersModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

async function storeImage(
  t: any,
  contentType: "image/jpeg" | "image/heic" | "image/heif",
  byteSize: number,
) {
  return await t.run(async (ctx) => {
    const bytes = new Uint8Array(byteSize).fill(1);
    return await ctx.storage.store(new Blob([bytes], { type: contentType }));
  });
}

async function createImageAsset(
  t: any,
  asUser: any,
  purpose: "userPhoto" | "taskerPhoto" | "taskerCategoryPortfolio",
) {
  const thumbSize = 12_000;
  const displaySize = 54_000;

  const thumbStorageId = await storeImage(t, "image/jpeg", thumbSize);
  const displayStorageId = await storeImage(t, "image/jpeg", displaySize);

  return await asUser.mutation(api.files.commitImageAsset, {
    purpose,
    sourceContentType: "image/jpeg",
    variants: [
      {
        kind: "thumb",
        storageId: thumbStorageId,
        contentType: "image/jpeg",
        width: 300,
        height: 300,
        byteSize: thumbSize,
      },
      {
        kind: "display",
        storageId: displayStorageId,
        contentType: "image/jpeg",
        width: 900,
        height: 900,
        byteSize: displaySize,
      },
    ],
  });
}

function storageIdsForAsset(asset: any) {
  return [
    asset.variants.thumb.storageId,
    asset.variants.display.storageId,
    asset.variants.large?.storageId,
  ].filter(Boolean);
}

async function expectStorageIdsDeleted(t: any, storageIds: string[]) {
  for (const storageId of storageIds) {
    const url = await t.run(async (ctx: any) => await ctx.storage.getUrl(storageId));
    expect(url).toBeNull();
  }
}

async function expectStorageIdsPresent(t: any, storageIds: string[]) {
  for (const storageId of storageIds) {
    const url = await t.run(async (ctx: any) => await ctx.storage.getUrl(storageId));
    expect(url).not.toBeNull();
  }
}

async function seedAndGetCategory(
  t: any,
  slug: string = "plumbing",
) {
  await t.mutation(internal.categories.seedCategories, {});
  const category = await t.query(api.categories.getCategoryBySlug, { slug });
  if (!category) {
    throw new Error(`Missing seeded category: ${slug}`);
  }
  return category;
}

describe("image asset contract", () => {
  test("files APIs require auth and getUrl is auth gated", async () => {
    const t = convexTest(schema, modules);

    await expect(
      t.mutation(api.files.generateImageAssetUploadUrls, {
        purpose: "userPhoto",
        variants: [
          { kind: "thumb", contentType: "image/jpeg", width: 256, height: 256, byteSize: 40_000 },
          { kind: "display", contentType: "image/jpeg", width: 1024, height: 1024, byteSize: 100_000 },
        ],
      })
    ).rejects.toThrow("Unauthorized");

    const thumbStorageId = await storeImage(t, "image/jpeg", 5_000);
    const displayStorageId = await storeImage(t, "image/jpeg", 8_000);

    await expect(
      t.mutation(api.files.commitImageAsset, {
        purpose: "userPhoto",
        sourceContentType: "image/jpeg",
        variants: [
          {
            kind: "thumb",
            storageId: thumbStorageId,
            contentType: "image/jpeg",
            width: 128,
            height: 128,
            byteSize: 5_000,
          },
          {
            kind: "display",
            storageId: displayStorageId,
            contentType: "image/jpeg",
            width: 700,
            height: 700,
            byteSize: 8_000,
          },
        ],
      })
    ).rejects.toThrow("Unauthorized");

    await expect(
      t.query(api.files.getUrl, {
        storageId: thumbStorageId,
      })
    ).rejects.toThrow("Not authenticated");
  });

  test("image upload validation rejects invalid dimensions, size, and metadata type mismatch", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|image_validation_user",
      email: "image_validation@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Validation User",
      city: "Toronto",
      province: "ON",
    });

    await expect(
      asUser.mutation(api.files.generateImageAssetUploadUrls, {
        purpose: "userPhoto",
        variants: [
          { kind: "thumb", contentType: "image/jpeg", width: 400, height: 250, byteSize: 80_000 },
          { kind: "display", contentType: "image/jpeg", width: 1200, height: 900, byteSize: 200_000 },
        ],
      })
    ).rejects.toThrow("thumb long edge must be 320px or less");

    await expect(
      asUser.mutation(api.files.generateImageAssetUploadUrls, {
        purpose: "userPhoto",
        variants: [
          { kind: "thumb", contentType: "image/jpeg", width: 300, height: 300, byteSize: 120_000 },
          { kind: "display", contentType: "image/jpeg", width: 1280, height: 1280, byteSize: 1_800_000 },
        ],
      })
    ).rejects.toThrow("display byte size must be 1572864 bytes or less");

    await expect(
      asUser.mutation(api.files.generateImageAssetUploadUrls, {
        purpose: "userPhoto",
        variants: [
          { kind: "thumb", contentType: "image/png" as any, width: 256, height: 256, byteSize: 40_000 },
          { kind: "display", contentType: "image/jpeg", width: 1024, height: 1024, byteSize: 120_000 },
        ],
      })
    ).rejects.toThrow("Validator error");

    const thumbStorageId = await storeImage(t, "image/jpeg", 10_000);
    const displayStorageId = await storeImage(t, "image/jpeg", 20_000);

    await expect(
      asUser.mutation(api.files.commitImageAsset, {
        purpose: "userPhoto",
        sourceContentType: "image/jpeg",
        variants: [
          {
            kind: "thumb",
            storageId: thumbStorageId,
            contentType: "image/jpeg",
            width: 200,
            height: 200,
            byteSize: 9_999,
          },
          {
            kind: "display",
            storageId: displayStorageId,
            contentType: "image/jpeg",
            width: 800,
            height: 800,
            byteSize: 20_000,
          },
        ],
      })
    ).rejects.toThrow("Stored byte size mismatch");
  });

  test("wrong-owner image assets are rejected in user/tasker flows", async () => {
    const t = convexTest(schema, modules);

    const asOwner = t.withIdentity({
      tokenIdentifier: "google|asset_owner",
      email: "asset_owner@example.com",
    });
    const asOther = t.withIdentity({
      tokenIdentifier: "google|asset_other",
      email: "asset_other@example.com",
    });

    await asOwner.mutation(api.users.createProfile, {
      name: "Owner",
      city: "Toronto",
      province: "ON",
    });
    await asOther.mutation(api.users.createProfile, {
      name: "Other",
      city: "Toronto",
      province: "ON",
    });

    const ownerUserPhoto = await createImageAsset(t, asOwner, "userPhoto");

    await expect(
      asOther.mutation(api.users.updateProfilePhoto, {
        photoAssetId: ownerUserPhoto._id,
      })
    ).rejects.toThrow("Image asset not found");

    const plumbing = await seedAndGetCategory(t, "plumbing");

    await asOther.mutation(api.taskers.createTaskerProfile, {
      displayName: "Other Tasker",
      categoryId: plumbing._id,
      categoryBio: "General plumbing",
      rateType: "hourly",
      hourlyRate: 6000,
      serviceRadius: 20,
    });

    await expect(
      asOther.mutation(api.taskers.setTaskerPhoto, {
        photoSource: "custom",
        photoAssetId: ownerUserPhoto._id,
      })
    ).rejects.toThrow("Image asset not found");
  });

  test("deleteImageAsset marks asset deleted and removes variant storage", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|delete_image_asset",
      email: "delete_image_asset@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Delete Image Asset",
      city: "Toronto",
      province: "ON",
    });

    const asset = await createImageAsset(t, asUser, "userPhoto");
    const storageIds = storageIdsForAsset(asset);

    const deleted = await asUser.mutation(api.files.deleteImageAsset, {
      imageAssetId: asset._id,
    });

    expect(deleted?.status).toBe("deleted");
    const storedAsset = await t.run(async (ctx) => await ctx.db.get(asset._id));
    expect(storedAsset?.status).toBe("deleted");
    await expectStorageIdsDeleted(t, storageIds);
  });

  test("deleteUncommittedImageUploads removes validated staged variant storage", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|delete_uncommitted_uploads",
      email: "delete_uncommitted_uploads@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Delete Uncommitted Uploads",
      city: "Toronto",
      province: "ON",
    });

    const thumbStorageId = await storeImage(t, "image/jpeg", 12_000);
    const displayStorageId = await storeImage(t, "image/jpeg", 54_000);

    await asUser.mutation(api.files.deleteUncommittedImageUploads, {
      variants: [
        {
          kind: "thumb",
          storageId: thumbStorageId,
          contentType: "image/jpeg",
          width: 300,
          height: 300,
          byteSize: 12_000,
        },
        {
          kind: "display",
          storageId: displayStorageId,
          contentType: "image/jpeg",
          width: 900,
          height: 900,
          byteSize: 54_000,
        },
      ],
    });

    await expectStorageIdsDeleted(t, [thumbStorageId, displayStorageId]);
  });

  test("deleteUncommittedImageUploads refuses committed image asset storage", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|delete_committed_upload_cleanup",
      email: "delete_committed_upload_cleanup@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Delete Committed Upload Cleanup",
      city: "Toronto",
      province: "ON",
    });

    const asset = await createImageAsset(t, asUser, "userPhoto");
    const storageIds = storageIdsForAsset(asset);

    await expect(
      asUser.mutation(api.files.deleteUncommittedImageUploads, {
        variants: [
          {
            kind: "thumb",
            storageId: asset.variants.thumb.storageId,
            contentType: asset.variants.thumb.contentType,
            width: asset.variants.thumb.width,
            height: asset.variants.thumb.height,
            byteSize: asset.variants.thumb.byteSize,
          },
          {
            kind: "display",
            storageId: asset.variants.display.storageId,
            contentType: asset.variants.display.contentType,
            width: asset.variants.display.width,
            height: asset.variants.display.height,
            byteSize: asset.variants.display.byteSize,
          },
        ],
      })
    ).rejects.toThrow("Storage file is already committed");

    await expectStorageIdsPresent(t, storageIds);
  });

  test("tasker photo can switch between user-linked and custom asset", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|tasker_photo_switch",
      email: "tasker_photo_switch@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Tasker Photo Switch",
      city: "Toronto",
      province: "ON",
    });

    const plumbing = await seedAndGetCategory(t, "plumbing");

    const userPhoto = await createImageAsset(t, asUser, "userPhoto");
    const customTaskerPhoto = await createImageAsset(t, asUser, "taskerPhoto");
    const customTaskerPhotoStorageIds = storageIdsForAsset(customTaskerPhoto);

    await asUser.mutation(api.users.updateProfilePhoto, {
      photoAssetId: userPhoto._id,
    });

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Tasker Photo",
      categoryId: plumbing._id,
      categoryBio: "Plumbing specialist",
      rateType: "hourly",
      hourlyRate: 9000,
      serviceRadius: 25,
    });

    const initialProfile = await asUser.query(api.taskers.getTaskerProfile);
    expect(initialProfile?.photoSource).toBe("user");
    expect(initialProfile?.photoImage?._id).toBe(userPhoto._id);

    const customProfile = await asUser.mutation(api.taskers.setTaskerPhoto, {
      photoSource: "custom",
      photoAssetId: customTaskerPhoto._id,
    });

    expect(customProfile.photoSource).toBe("custom");
    expect(customProfile.photoImage?._id).toBe(customTaskerPhoto._id);

    const userLinkedProfile = await asUser.mutation(api.taskers.setTaskerPhoto, {
      photoSource: "user",
    });

    expect(userLinkedProfile.photoSource).toBe("user");
    expect(userLinkedProfile.photoImage?._id).toBe(userPhoto._id);

    const storedCustomPhoto = await t.run(async (ctx) => await ctx.db.get(customTaskerPhoto._id));
    expect(storedCustomPhoto?.status).toBe("deleted");
    await expectStorageIdsDeleted(t, customTaskerPhotoStorageIds);
  });

  test("user profile photo replacement and removal cleanup unreferenced image assets", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|profile_photo_cleanup",
      email: "profile_photo_cleanup@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Profile Photo Cleanup",
      city: "Toronto",
      province: "ON",
    });

    const firstPhoto = await createImageAsset(t, asUser, "userPhoto");
    const secondPhoto = await createImageAsset(t, asUser, "userPhoto");
    const firstStorageIds = storageIdsForAsset(firstPhoto);
    const secondStorageIds = storageIdsForAsset(secondPhoto);

    await asUser.mutation(api.users.updateProfilePhoto, {
      photoAssetId: firstPhoto._id,
    });
    await asUser.mutation(api.users.updateProfilePhoto, {
      photoAssetId: secondPhoto._id,
    });

    let storedFirstPhoto = await t.run(async (ctx) => await ctx.db.get(firstPhoto._id));
    expect(storedFirstPhoto?.status).toBe("deleted");
    await expectStorageIdsDeleted(t, firstStorageIds);

    await asUser.mutation(api.users.updateProfilePhoto, {
      photoAssetId: null,
    });

    const currentUser = await asUser.query(api.users.getCurrentUser, {});
    expect(currentUser?.photoAssetId).toBeUndefined();
    const storedSecondPhoto = await t.run(async (ctx) => await ctx.db.get(secondPhoto._id));
    expect(storedSecondPhoto?.status).toBe("deleted");
    await expectStorageIdsDeleted(t, secondStorageIds);
  });

  test("setCategoryPortfolio enforces max/unique/cover and updates compatibility order", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|category_portfolio",
      email: "category_portfolio@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Category Portfolio",
      city: "Toronto",
      province: "ON",
    });

    const plumbing = await seedAndGetCategory(t, "plumbing");

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Portfolio Tasker",
      categoryId: plumbing._id,
      categoryBio: "Portfolio bio",
      rateType: "hourly",
      hourlyRate: 6500,
      serviceRadius: 20,
    });

    const assets = await Promise.all(
      Array.from({ length: 11 }).map(async () => createImageAsset(t, asUser, "taskerCategoryPortfolio"))
    );

    await expect(
      asUser.mutation(api.taskers.setCategoryPortfolio, {
        categoryId: plumbing._id,
        portfolioAssetIds: assets.map((asset) => asset._id),
      })
    ).rejects.toThrow("Maximum 10 portfolio images allowed");

    const [a, b, c] = assets;

    await expect(
      asUser.mutation(api.taskers.setCategoryPortfolio, {
        categoryId: plumbing._id,
        portfolioAssetIds: [a._id, a._id],
      })
    ).rejects.toThrow("Portfolio image assets must be unique");

    await expect(
      asUser.mutation(api.taskers.setCategoryPortfolio, {
        categoryId: plumbing._id,
        portfolioAssetIds: [a._id, c._id],
        coverAssetId: b._id,
      })
    ).rejects.toThrow("coverAssetId must exist in portfolioAssetIds");

    await asUser.mutation(api.taskers.setCategoryPortfolio, {
      categoryId: plumbing._id,
      portfolioAssetIds: [a._id, b._id, c._id],
      coverAssetId: b._id,
    });

    let profile = await asUser.query(api.taskers.getTaskerProfile);
    const category = profile?.categories.find((entry) => entry.categoryId === plumbing._id);

    expect(category?.coverAssetId).toBe(b._id);
    expect(category?.photos).toEqual([
      b.variants.display.storageId,
      a.variants.display.storageId,
      c.variants.display.storageId,
    ]);

    await asUser.mutation(api.taskers.setCategoryPortfolio, {
      categoryId: plumbing._id,
      portfolioAssetIds: [c._id, a._id, b._id],
      coverAssetId: c._id,
    });

    profile = await asUser.query(api.taskers.getTaskerProfile);
    const reorderedCategory = profile?.categories.find((entry) => entry.categoryId === plumbing._id);

    expect(reorderedCategory?.coverAssetId).toBe(c._id);
    expect(reorderedCategory?.photos).toEqual([
      c.variants.display.storageId,
      a.variants.display.storageId,
      b.variants.display.storageId,
    ]);
  });

  test("addTaskerCategory accepts portfolioAssetIds and coverAssetId", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|add_category_portfolio",
      email: "add_category_portfolio@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Add Category Portfolio",
      city: "Toronto",
      province: "ON",
    });

    const plumbing = await seedAndGetCategory(t, "plumbing");
    const electrical = await seedAndGetCategory(t, "electrical");

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Add Category Tasker",
      categoryId: plumbing._id,
      categoryBio: "Initial category",
      rateType: "hourly",
      hourlyRate: 7000,
      serviceRadius: 20,
    });

    const a = await createImageAsset(t, asUser, "taskerCategoryPortfolio");
    const b = await createImageAsset(t, asUser, "taskerCategoryPortfolio");
    const c = await createImageAsset(t, asUser, "taskerCategoryPortfolio");

    const result = await asUser.mutation(api.taskers.addTaskerCategory, {
      categoryId: electrical._id,
      categoryBio: "Electrical category with portfolio",
      portfolioAssetIds: [a._id, b._id, c._id],
      coverAssetId: b._id,
      rateType: "fixed",
      fixedRate: 20000,
      serviceRadius: 35,
    });
    expect(result).toBeNull();

    const profile = await asUser.query(api.taskers.getTaskerProfile);
    const category = profile?.categories.find((entry) => entry.categoryId === electrical._id);

    expect(category?.portfolioAssetIds).toEqual([a._id, b._id, c._id]);
    expect(category?.coverAssetId).toBe(b._id);
    expect(category?.photos).toEqual([
      b.variants.display.storageId,
      a.variants.display.storageId,
      c.variants.display.storageId,
    ]);
  });

  test("updateTaskerCategory updates details and portfolio atomically and cleans removed assets", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|update_category_with_portfolio",
      email: "update_category_with_portfolio@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Update Category Portfolio",
      city: "Toronto",
      province: "ON",
    });

    const plumbing = await seedAndGetCategory(t, "plumbing");

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Update Category Tasker",
      categoryId: plumbing._id,
      categoryBio: "Original category bio",
      rateType: "hourly",
      hourlyRate: 6500,
      serviceRadius: 20,
    });

    const a = await createImageAsset(t, asUser, "taskerCategoryPortfolio");
    const b = await createImageAsset(t, asUser, "taskerCategoryPortfolio");
    const c = await createImageAsset(t, asUser, "taskerCategoryPortfolio");
    const d = await createImageAsset(t, asUser, "taskerCategoryPortfolio");
    const bStorageIds = storageIdsForAsset(b);

    await asUser.mutation(api.taskers.setCategoryPortfolio, {
      categoryId: plumbing._id,
      portfolioAssetIds: [a._id, b._id, c._id],
      coverAssetId: a._id,
    });

    const updatedProfile = await asUser.mutation(api.taskers.updateTaskerCategory, {
      categoryId: plumbing._id,
      categoryBio: "Updated category bio",
      portfolioAssetIds: [c._id, a._id, d._id],
      coverAssetId: d._id,
      rateType: "fixed",
      fixedRate: 18000,
      serviceRadius: 45,
    });

    const category = updatedProfile.categories.find((entry) => entry.categoryId === plumbing._id);
    expect(category?.bio).toBe("Updated category bio");
    expect(category?.rateType).toBe("fixed");
    expect(category?.hourlyRate).toBeUndefined();
    expect(category?.fixedRate).toBe(18000);
    expect(category?.serviceRadius).toBe(45);
    expect(category?.portfolioAssetIds).toEqual([c._id, a._id, d._id]);
    expect(category?.coverAssetId).toBe(d._id);
    expect(category?.photos).toEqual([
      d.variants.display.storageId,
      c.variants.display.storageId,
      a.variants.display.storageId,
    ]);

    const storedRemovedAsset = await t.run(async (ctx) => await ctx.db.get(b._id));
    expect(storedRemovedAsset?.status).toBe("deleted");
    await expectStorageIdsDeleted(t, bStorageIds);
    await expectStorageIdsPresent(t, [
      ...storageIdsForAsset(a),
      ...storageIdsForAsset(c),
      ...storageIdsForAsset(d),
    ]);
  });

  test("portfolio updates and category removal cleanup unreferenced image assets", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|portfolio_cleanup",
      email: "portfolio_cleanup@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Portfolio Cleanup",
      city: "Toronto",
      province: "ON",
    });

    const plumbing = await seedAndGetCategory(t, "plumbing");

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Portfolio Cleanup Tasker",
      categoryId: plumbing._id,
      categoryBio: "Portfolio cleanup bio",
      rateType: "hourly",
      hourlyRate: 6500,
      serviceRadius: 20,
    });

    const a = await createImageAsset(t, asUser, "taskerCategoryPortfolio");
    const b = await createImageAsset(t, asUser, "taskerCategoryPortfolio");
    const c = await createImageAsset(t, asUser, "taskerCategoryPortfolio");
    const bStorageIds = storageIdsForAsset(b);
    const remainingStorageIds = [
      ...storageIdsForAsset(a),
      ...storageIdsForAsset(c),
    ];

    await asUser.mutation(api.taskers.setCategoryPortfolio, {
      categoryId: plumbing._id,
      portfolioAssetIds: [a._id, b._id, c._id],
      coverAssetId: a._id,
    });

    await asUser.mutation(api.taskers.setCategoryPortfolio, {
      categoryId: plumbing._id,
      portfolioAssetIds: [a._id, c._id],
      coverAssetId: c._id,
    });

    const storedRemovedAsset = await t.run(async (ctx) => await ctx.db.get(b._id));
    expect(storedRemovedAsset?.status).toBe("deleted");
    await expectStorageIdsDeleted(t, bStorageIds);

    await asUser.mutation(api.taskers.removeTaskerCategory, {
      categoryId: plumbing._id,
    });

    const [storedA, storedC] = await Promise.all([
      t.run(async (ctx) => await ctx.db.get(a._id)),
      t.run(async (ctx) => await ctx.db.get(c._id)),
    ]);
    expect(storedA?.status).toBe("deleted");
    expect(storedC?.status).toBe("deleted");
    await expectStorageIdsDeleted(t, remainingStorageIds);
  });
});
