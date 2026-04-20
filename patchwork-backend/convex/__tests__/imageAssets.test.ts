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
});
