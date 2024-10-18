defmodule PlausibleWeb.RefInspector do
  @custom_sources %{
    "android-app://com.reddit.frontpage" => "Reddit",
    "perplexity.ai" => "Perplexity",
    "search.brave.com" => "Brave",
    "yandex.com.tr" => "Yandex",
    "yandex.kz" => "Yandex",
    "ya.ru" => "Yandex",
    "yandex.uz" => "Yandex",
    "yandex.fr" => "Yandex",
    "yandex.eu" => "Yandex",
    "yandex.tm" => "Yandex",
    "discord.com" => "Discord",
    "t.me" => "Telegram",
    "webk.telegram.org" => "Telegram",
    "sogou.com" => "Sogou",
    "m.sogou.com" => "Sogou",
    "wap.sogou.com" => "Sogou",
    "canary.discord.com" => "Discord",
    "ptb.discord.com" => "Discord",
    "discordapp.com" => "Discord",
    "linktr.ee" => "Linktree",
    "baidu.com" => "Baidu",
    "statics.teams.cdn.office.net" => "Microsoft Teams",
    "ntp.msn.com" => "Bing"
  }

  def parse(nil), do: nil

  def parse(ref) do
    case ref.source do
      :unknown ->
        uri = URI.parse(String.trim(ref.referer))

        if right_uri?(uri) do
          format_referrer_host(uri)
          |> maybe_map_to_custom_source()
        end

      source ->
        source
    end
  end

  def format_referrer(uri) do
    path = String.trim_trailing(uri.path || "", "/")
    format_referrer_host(uri) <> path
  end

  def right_uri?(%URI{host: nil}), do: false

  def right_uri?(%URI{host: host, scheme: scheme})
      when scheme in ["http", "https", "android-app"] and byte_size(host) > 0,
      do: true

  def right_uri?(_), do: false

  defp format_referrer_host(uri) do
    protocol = if uri.scheme == "android-app", do: "android-app://", else: ""
    host = String.replace_prefix(uri.host, "www.", "")

    protocol <> host
  end

  defp maybe_map_to_custom_source(source) do
    Map.get(@custom_sources, source, source)
  end
end
