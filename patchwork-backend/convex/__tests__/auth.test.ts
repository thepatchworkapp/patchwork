import { describe, expect, test } from "vitest";
import {
  AUTH_SESSION_EXPIRES_IN_SECONDS,
  AUTH_SESSION_UPDATE_AGE_SECONDS,
} from "../auth";

describe("auth session configuration", () => {
  test("keeps Better Auth sessions alive for 90 days", () => {
    expect(AUTH_SESSION_EXPIRES_IN_SECONDS).toBe(60 * 60 * 24 * 90);
    expect(AUTH_SESSION_UPDATE_AGE_SECONDS).toBe(60 * 60 * 24);
  });
});
