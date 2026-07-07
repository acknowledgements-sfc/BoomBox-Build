import { describe, expect, it } from "vitest";
import { configureAllowedOrigins, isAuthorized, isOriginAllowed } from "../src/auth.js";

describe("isAuthorized", () => {
  const token = "test-bridge-token";

  it("accepts a valid bearer token", () => {
    expect(isAuthorized(`Bearer ${token}`, token)).toBe(true);
  });

  it("rejects missing authorization", () => {
    expect(isAuthorized(undefined, token)).toBe(false);
  });

  it("rejects wrong token", () => {
    expect(isAuthorized("Bearer wrong-token", token)).toBe(false);
  });

  it("rejects malformed header", () => {
    expect(isAuthorized("Basic abc", token)).toBe(false);
  });
});

describe("isOriginAllowed", () => {
  it("allows missing origin for CLI clients", () => {
    expect(isOriginAllowed(undefined)).toBe(true);
  });

  it("rejects unknown origin when allowlist is configured", () => {
    configureAllowedOrigins(["https://claude.ai"]);
    expect(isOriginAllowed("https://evil.example")).toBe(false);
    expect(isOriginAllowed("https://claude.ai")).toBe(true);
  });
});
