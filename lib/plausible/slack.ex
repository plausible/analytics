defmodule Plausible.Slack do
  @app_env System.get_env("APP_ENV") || "dev"
  @feed_channel_url "https://hooks.slack.com/services/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"

  def notify(text) do
    Task.start(fn ->
      case @app_env do
        "prod" ->
          HTTPoison.post!(@feed_channel_url, Poison.encode!(%{text: text}))
        _ ->
          nil
      end
    end)
  end
end
