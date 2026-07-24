defmodule PlausibleWeb.Captcha do
  alias Plausible.HTTPClient

  @verify_endpoint "https://global.frcapi.com/api/v2/captcha/siteverify"

  def enabled? do
    is_binary(sitekey())
  end

  def sitekey() do
    Application.get_env(:plausible, :friendly_captcha, [])[:sitekey]
  end

  def verify(token) do
    if enabled?() do
      res =
        HTTPClient.impl().post(
          @verify_endpoint,
          [{"content-type", "application/json"}, {"x-api-key", api_key()}],
          %{
            response: token,
            sitekey: sitekey()
          }
        )

      case res do
        {:ok, %Finch.Response{status: 200, body: %{"success" => success}}} ->
          success

        _ ->
          false
      end
    else
      true
    end
  end

  defp api_key() do
    Application.get_env(:plausible, :friendly_captcha, [])[:api_key]
  end
end
