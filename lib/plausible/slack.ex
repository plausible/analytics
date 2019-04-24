defmodule Plausible.Slack do
  @app_env System.get_env("APP_ENV") || "dev"
  @feed_channel_url "https://hooks.slack.com/services/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"

  def notify(text) do
    Task.start(fn ->
      case @app_env do
        "prod" ->
          HTTPoison.post!(@feed_channel_url, Poison.encode!(%{
            text: text,
            icon_url: "https://plausible.io/images/icon/plausible_favicon.png"
          }))
        _ ->
          nil
      end
    end)
  end
end
