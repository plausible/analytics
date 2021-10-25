defmodule Plausible.Slack do
  require Logger

  def notify(text) do
    Task.start(fn ->
      if env() == "prod" && !self_hosted() do
        HTTPoison.post!(webhook_url(), Jason.encode!(%{text: text}))
      else
        Logger.debug(text)
      end
    end)
  end

  defp webhook_url() do
    Keyword.fetch!(Application.get_env(:plausible, :slack), :webhook)
  end

  defp env() do
    Application.get_env(:plausible, :environment)
  end

  defp self_hosted() do
    Application.get_env(:plausible, :is_selfhost)
  end
end
