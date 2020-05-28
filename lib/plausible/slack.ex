defmodule Plausible.Slack do
  @app_env System.get_env("ENVIRONMENT") || "dev"
  require Logger

  def notify(text) do
    Task.start(fn ->
      case @app_env do
        "prod" ->
          HTTPoison.post!(webhook_url(), Poison.encode!(%{text: text}))
        _ ->
          Logger.debug(text)
      end
    end)
  end

  defp webhook_url() do
    Keyword.fetch!(Application.get_env(:plausible, :slack), :webhook)
  end
end
