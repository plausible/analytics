defmodule Plausible.IngestRepo.Migrations.RemapSourcesV3 do
  use Ecto.Migration

  @mappings %{
    "twitter" => "X (Twitter)",
    "x.com" => "X (Twitter)",
    "twitter-ads" => "X (Twitter)",
    "mobile.twitter.com" => "X (Twitter)",
    "bsky.app" => "Bluesky",
    "go.bsky.app" => "Bluesky",
    "chatgpt.com" => "ChatGPT",
    "chat.openai.com" => "ChatGPT",
    "claude.ai" => "Claude",
    "phind.com" => "Phind",
    "deepseek.com" => "DeepSeek",
    "copilot" => "Microsoft Copilot",
    "copilot.microsoft.com" => "Microsoft Copilot",
    "copilot.com" => "Microsoft Copilot",
    "grok.com" => "Grok",
    "x.ai" => "Grok",
    "gemini.google.com" => "Google Gemini",
    "pplx.ai" => "Perplexity",
    "kagi.com" => "Kagi",
    "l.threads.com" => "Threads",
    "mastodon.social" => "Mastodon",
    "mastodon.online" => "Mastodon",
    "mastodon.world" => "Mastodon",
    "fosstodon.org" => "Mastodon",
    "hachyderm.io" => "Mastodon",
    "infosec.exchange" => "Mastodon",
    "mas.to" => "Mastodon",
    "sigmoid.social" => "Mastodon",
    "mstdn.social" => "Mastodon",
    "indieweb.social" => "Mastodon",
    "mathstodon.xyz" => "Mastodon",
    "scholar.social" => "Mastodon",
    "chaos.social" => "Mastodon",
    "social.tchncs.de" => "Mastodon",
    "mstdn.jp" => "Mastodon"
  }

  @suffix_mappings %{
    "officeapps.live.com" => "Microsoft 365",
    "wikipedia.org" => "Wikipedia"
  }

  def up do
    {keys, values} = Enum.unzip(@mappings)

    suffix_match =
      Enum.map_join(Enum.sort(@suffix_mappings), " OR ", fn {suffix, _name} ->
        suffix_condition(suffix)
      end)

    suffix_cases =
      Enum.map_join(Enum.sort(@suffix_mappings), "\n          ", fn {suffix, name} ->
        "WHEN #{suffix_condition(suffix)} THEN '#{name}'"
      end)

    for table <- ["events_v2", "sessions_v2"] do
      sql = """
        ALTER TABLE #{table}
        UPDATE referrer_source =
          CASE
          #{suffix_cases}
          WHEN lower(referrer_source) IN {$0:Array(String)} THEN transform(lower(referrer_source), {$0:Array(String)}, {$1:Array(String)})
          ELSE referrer_source
          END
        WHERE lower(referrer_source) IN {$0:Array(String)} OR #{suffix_match}
      """

      execute(fn -> repo().query!(sql, [keys, values]) end)
    end
  end

  defp suffix_condition(suffix) do
    "lower(referrer_source) = '#{suffix}' OR endsWith(lower(referrer_source), '.#{suffix}')"
  end

  def down do
    raise "irreversible"
  end
end
