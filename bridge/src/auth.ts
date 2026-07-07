import { timingSafeEqual } from "node:crypto";
import type { BridgeEnv } from "./types.js";

export function loadBridgeEnv(): BridgeEnv {
  const bridgeToken = process.env.BRIDGE_TOKEN;
  const supabaseDbUrl = process.env.SUPABASE_DB_URL;
  const supabaseSecretKey = process.env.SUPABASE_SECRET_KEY;

  if (!bridgeToken || bridgeToken.trim().length === 0) {
    throw new Error("BRIDGE_TOKEN is required");
  }
  if (!supabaseDbUrl || supabaseDbUrl.trim().length === 0) {
    throw new Error("SUPABASE_DB_URL is required");
  }
  if (!supabaseSecretKey || supabaseSecretKey.trim().length === 0) {
    throw new Error("SUPABASE_SECRET_KEY is required");
  }

  return {
    bridgeToken,
    supabaseDbUrl,
    supabaseSecretKey,
  };
}

export function isAuthorized(
  authorizationHeader: string | string[] | undefined,
  bridgeToken: string,
): boolean {
  const header = Array.isArray(authorizationHeader)
    ? authorizationHeader[0]
    : authorizationHeader;

  if (!header) {
    return false;
  }

  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match || !match[1]) {
    return false;
  }

  const provided = Buffer.from(match[1], "utf8");
  const expected = Buffer.from(bridgeToken, "utf8");

  if (provided.length !== expected.length) {
    return false;
  }

  return timingSafeEqual(provided, expected);
}

const ALLOWED_ORIGINS = new Set<string>();

export function configureAllowedOrigins(origins: string[]): void {
  for (const origin of origins) {
    if (origin.trim().length > 0) {
      ALLOWED_ORIGINS.add(origin.trim());
    }
  }
}

export function isOriginAllowed(originHeader: string | string[] | undefined): boolean {
  const origin = Array.isArray(originHeader) ? originHeader[0] : originHeader;
  if (!origin) {
    return true;
  }
  if (ALLOWED_ORIGINS.size === 0) {
    return true;
  }
  return ALLOWED_ORIGINS.has(origin);
}
