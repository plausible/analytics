import type { CandidateMatch, MatcherPlugin } from "deepsec/config";
import { regexMatcher } from "deepsec/config";

/**
 * Mix tasks are CLI entry points. Several Plausible tasks take argv values such
 * as filenames, ids, URLs, and subscription ids, then call app code or external
 * services. Default matchers only accidentally hit a task when another generic
 * regex fires.
 *
 * Tier: normal — `run/1` is broad, but the path glob is limited to first-party
 * tasks and the AI can distinguish local maintenance-only tasks from risky
 * untrusted-input handling.
 */
export const mixTaskEntrypoint: MatcherPlugin = {
  slug: "plausible-mix-task-entrypoint",
  description: "Mix task run/1 callbacks — CLI entry points with argv input",
  noiseTier: "normal",
  filePatterns: ["lib/mix/tasks/**/*.ex"],
  examples: [
    "defmodule Mix.Tasks.ImportSomething do\n  use Mix.Task\n  def run([filename]) do",
    "  def run(opts) do\n    Mix.Task.run(\"app.start\")\n  end",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];

    return regexMatcher(
      "plausible-mix-task-entrypoint",
      [
        { regex: /^\s*use\s+Mix\.Task\b/m, label: "Mix task module" },
        { regex: /^\s*def\s+run\s*\(/m, label: "Mix task run/1 CLI entry point" },
      ],
      content,
    );
  },
};
