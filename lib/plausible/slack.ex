defmodule Plausible.Slack do
  @app_env System.get_env("APP_ENV") || "dev"
  @feed_channel_url "https://hooks.slack.com/services/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"
  require Logger

  def notify(text) do
    Task.start(fn ->
      case @app_env do
        "prod" ->
          HTTPoison.post!(@feed_channel_url, Poison.encode!(%{text: text}))
        _ ->
          Logger.debug(text)
      end
    end)
  end
end
