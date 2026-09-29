// Shared entity/DTO types for the app. See CLAUDE.md: "Shared types (entities, DTOs) go in `src/types.ts`."

/** Mirrors the `status` check constraint on `public.analyses`. */
export type AnalysisStatus = "open" | "resolved";

/** Mirrors the `severity` check constraint on `public.analysis_suggestions`. */
export type AnalysisSeverity = "high" | "medium" | "low";

/**
 * Entity for the `public.analyses` table.
 * Field names are camelCase; mapping from snake_case DB columns is the
 * responsibility of the repository/service layer, not this file.
 */
export interface Analysis {
  id: string;
  ownerId: string;
  queryText: string;
  status: AnalysisStatus;
  createdAt: string;
  updatedAt: string;
}

/**
 * Entity for the `public.analysis_suggestions` table.
 * Field names are camelCase; mapping from snake_case DB columns is the
 * responsibility of the repository/service layer, not this file.
 */
export interface AnalysisSuggestion {
  id: string;
  analysisId: string;
  ruleCode: string;
  message: string;
  severity: AnalysisSeverity;
  position: number;
  createdAt: string;
}
