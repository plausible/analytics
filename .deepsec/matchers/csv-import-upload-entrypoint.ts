import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * CSV import and upload boundary.
 *
 * CSV imports take browser-supplied upload metadata, presign S3 or move local
 * files, parse filenames into table/date parameters, and stream content into
 * ClickHouse. The LiveView matcher sees the websocket events, but not the file
 * handling/import service as its own risky boundary.
 */
export const csvImportUploadEntrypoint: MatcherPlugin = {
  slug: "plausible-csv-import-upload-entrypoint",
  description:
    "CSV import/upload metadata, S3 presigning, local file movement, filename parsing, and ClickHouse import",
  noiseTier: "normal",
  filePatterns: [
    "lib/plausible_web/live/csv_import.ex",
    "lib/plausible_web/live/imports_exports_settings.ex",
    "lib/plausible/imported/**/*.ex",
    "lib/plausible/s3.ex",
    "lib/workers/import_analytics.ex",
    "lib/workers/local_import_analytics_cleaner.ex",
  ],
  examples: [
    "  |> allow_upload(:import, upload_opts)",
    "  uploads = consume_uploaded_entries(socket, :import, upload_consumer)",
    "  def parse_filename!(filename)",
    "  File.stream!(local_path, 512_000) |> Stream.into(Ch.stream(conn, statement, params))",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];
    if (/\.(test|spec)\.(ex|exs)$/.test(filePath)) return [];

    return regexMatcher(
      "plausible-csv-import-upload-entrypoint",
      [
        {
          regex: /\b(?:allow_upload|consume_uploaded_entries|uploaded_entries|cancel_upload)\s*\(/,
          label: "LiveView upload lifecycle",
        },
        {
          regex: /\b(?:entry|upload)\.client_name\b/,
          label: "Browser-supplied upload filename",
        },
        {
          regex: /\b(?:presign_upload|import_presign_upload|ExAws\.S3\.presigned_url)\s*\(/,
          label: "Presigned upload URL generation",
        },
        {
          regex: /\b(?:Path\.basename|Path\.join|Plausible\.File\.mv!|File\.(?:mkdir_p!|stream!|rm))\s*\(/,
          label: "Upload path or local file operation",
        },
        {
          regex: /^\s*def\s+(?:parse_args|import_data|parse_filename!|valid_filename\?|extract_table|date_range|local_dir)\s*\(/m,
          label: "CSV import service consumes upload metadata",
        },
        {
          regex: /\b(?:FROM\s+s3\s*\(|FROM\s+input\s*\(|Ch\.(?:query!|stream)|ClickHouse|Clickhouse)\b/i,
          label: "CSV import reaches ClickHouse",
        },
        {
          regex: /\bOban\.insert!\s*\(\s*Plausible\.Workers\.LocalImportAnalyticsCleaner\.new\b/,
          label: "Local upload cleanup worker scheduled from import args",
        },
      ],
      content,
    );
  },
};
