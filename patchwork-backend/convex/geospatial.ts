import { GeospatialIndex } from "@convex-dev/geospatial";
import { components } from "./_generated/api";
import { Id } from "./_generated/dataModel";

export const taskerGeo = new GeospatialIndex<
  Id<"taskerProfiles">,
  { categoryId: string }
>(components.geospatial);
