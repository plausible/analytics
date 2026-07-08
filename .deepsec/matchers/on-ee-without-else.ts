import type { CandidateMatch, MatcherPlugin } from "deepsec/config";

/**
 * `on_ee do ... end` blocks without an `else` branch.
 *
 * The `on_ee` macro compiles two code paths:
 *   on_ee do
 *     def super_admin?(%User{id: id}), do: id in @ids   # EE path
 *   else
 *     def super_admin?(_), do: always(false)             # CE path
 *   end
 *
 * A missing `else` means the CE build silently omits the entire block. For
 * feature display flags this is intentional; for auth checks it can leave
 * a CE route unprotected.
 *
 * Tier: normal — the AI must distinguish "intentional EE-only feature" from
 * "missing CE auth fallback". Uses manual line-scanning to track nesting depth
 * rather than regexMatcher, since we need to detect the else at exactly depth 1.
 */
export const onEeWithoutElse: MatcherPlugin = {
  slug: "plausible-on-ee-no-else",
  description: "on_ee do block without else branch — CE build silently omits this block",
  noiseTier: "normal",
  filePatterns: [
    "lib/plausible_web/**/*.ex",
    "lib/plausible/auth/**/*.ex",
    "extra/lib/plausible_web/**/*.ex",
  ],
  examples: [
    "  on_ee do\n    def super_admin?(nil), do: false\n  end",
    "  on_ee do\n    plug :require_admin\n  end",
  ],
  match(content, filePath): CandidateMatch[] {
    if (/\/(test|tests)\//.test(filePath)) return [];

    const lines = content.split("\n");
    const matches: CandidateMatch[] = [];

    for (let i = 0; i < lines.length; i++) {
      if (!/^\s*on_ee\s+do\s*$/.test(lines[i])) continue;

      let depth = 1;
      let hasElse = false;
      let endLine = i;

      for (let j = i + 1; j < lines.length && j < i + 80; j++) {
        const line = lines[j];
        if (/^\s*#/.test(line)) continue;
        if (/\bdo\b/.test(line)) depth++;
        if (/^\s*end\b/.test(line)) {
          depth--;
          if (depth === 0) { endLine = j; break; }
        }
        if (depth === 1 && /^\s*else\s*$/.test(line)) hasElse = true;
      }

      if (!hasElse) {
        const start = Math.max(0, i - 1);
        const end = Math.min(lines.length, endLine + 2);
        matches.push({
          vulnSlug: "plausible-on-ee-no-else",
          lineNumbers: [i + 1],
          snippet: lines.slice(start, Math.min(end, start + 15)).join("\n"),
          matchedPattern: "on_ee do without else — CE build omits this block",
        });
      }
    }

    return matches;
  },
};
