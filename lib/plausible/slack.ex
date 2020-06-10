defmodule Plausible.Slack do
  require Logger

  def notify(text) do
    Task.start(fn ->
      case Application.get_env(:plausible, :environment) do
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
