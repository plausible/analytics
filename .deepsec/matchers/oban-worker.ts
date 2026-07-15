import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * Oban workers are queue consumers. Many are scheduled internally, but job
 * arguments can also originate from HTTP handlers, imports, third-party
 * callbacks, or admin-triggered workflows. The built-in matchers do not cover
 * Oban's `perform/1` boundary.
 *
 * Tier: noisy — every worker perform callback should be reviewed as an async
 * entry point for tenant scoping, authorization assumptions, and unsafe use of
 * job args.
 */
export const obanWorker: MatcherPlugin = {
  slug: "plausible-oban-worker",
  description: "Oban worker perform callbacks — async queue entry points",
  noiseTier: "noisy",
  filePatterns: [
    "lib/workers/**/*.ex",
    "extra/lib/**/worker.ex",
    "extra/lib/**/*worker*.ex",
  ],
  examples: [
    "  use Oban.Worker, queue: :imports\n\n  def perform(%Oban.Job{args: args}) do",
    "  def perform(%{\"domain\" => domain}) do",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];

    return regexMatcher(
      "plausible-oban-worker",
      [
        { regex: /\buse\s+Oban\.Worker\b/, label: "Oban worker module" },
        { regex: /^\s*def\s+perform\s*\(/m, label: "Oban perform callback entry point" },
      ],
      content,
    );
  },
};
