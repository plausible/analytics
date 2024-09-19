defmodule Plausible.IngestRepo.Migrations.RemapSources do
  use Ecto.Migration

  @mappings %{
    "android-app://com.reddit.frontpage" => "Reddit",
    "perplexity.ai" => "Perplexity",
    "perplexity" => "Perplexity",
    "search.brave.com" => "Brave",
    "python.orgyandex.com.tr" => "Yandex",
    "yandex.kz" => "Yandex",
    "ya.ru" => "Yandex",
    "yandex.uz" => "Yandex",
    "yandex.fr" => "Yandex",
    "yandex.eu" => "Yandex",
    "yandex.tm" => "Yandex",
    "discord.com" => "Discord",
    "t.me" => "Telegram",
    "webk.telegram.org" => "Telegram",
    "canary.discord.com" => "Discord",
    "ptb.discord.com" => "Discord",
    "discordapp.com" => "Discord",
    "baidu.com" => "Baidu",
    "ig" => "Instagram",
    "fb" => "Facebook"
  }

  def up do
    {keys, values} = Enum.unzip(@mappings)

    events_sql = """
      ALTER TABLE events_v2
      UPDATE referrer_source = transform(referrer_source, {$0:Array(String)}, {$1:Array(String)})
      WHERE referrer_source IN {$0:Array(String)}
    """

    sessions_sql = """
      ALTER TABLE sessions_v2
      UPDATE referrer_source = transform(referrer_source, {$0:Array(String)}, {$1:Array(String)})
      WHERE referrer_source IN {$0:Array(String)}
    """

    execute(fn -> repo().query!(events_sql, [keys, values]) end)
    execute(fn -> repo().query!(sessions_sql, [keys, values]) end)
  end

  def down do
    raise "irreversible"
  end
end
