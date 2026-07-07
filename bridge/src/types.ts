export const ACTIVE_STATUSES = ["requested", "in_progress", "blocked"] as const;
export const ALL_STATUSES = [
  "requested",
  "in_progress",
  "blocked",
  "completed",
  "abandoned",
] as const;

export type BuildStatus = (typeof ALL_STATUSES)[number];

export interface BridgeBuild {
  id: string;
  track: string;
  task_id: string;
  spec: string;
  model: string | null;
  status: BuildStatus;
  verification: Record<string, unknown> | null;
  hot_files: string[];
  requested_by: string;
  created_at: string;
  updated_at: string;
}

export interface BridgeState {
  id: number;
  current_slice: string | null;
  current_status: string | null;
  open_hot_files: string[];
  last_updated: string;
}

export interface HotFileConflict {
  id: string;
  task_id: string;
  hot_files: string[];
  overlapping: string[];
}

export interface BridgeEnv {
  bridgeToken: string;
  supabaseDbUrl: string;
  supabaseSecretKey: string;
}
