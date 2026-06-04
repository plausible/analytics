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

    for table <- ["events_v2", "sessions_v2"] do
      transform_sql = """
        ALTER TABLE #{table}
        UPDATE referrer_source = transform(lower(referrer_source), {$0:Array(String)}, {$1:Array(String)})
        WHERE lower(referrer_source) IN {$0:Array(String)}
      """

      execute(fn -> repo().query!(transform_sql, [keys, values]) end)

      for {suffix, name} <- @suffix_mappings do
        suffix_sql = """
          ALTER TABLE #{table}
          UPDATE referrer_source = {$0:String}
          WHERE referrer_source != {$0:String}
            AND (lower(referrer_source) = {$1:String} OR endsWith(lower(referrer_source), {$2:String}))
        """

        execute(fn -> repo().query!(suffix_sql, [name, suffix, "." <> suffix]) end)
      end
    end
  end

  def down do
    raise "irreversible"
  end
end
