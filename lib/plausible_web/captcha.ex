defmodule PlausibleWeb.Captcha do
  alias Plausible.HTTPClient

  @verify_endpoint "https://hcaptcha.com/siteverify"

  def enabled? do
    is_binary(sitekey())
  end

  def sitekey() do
    Application.get_env(:plausible, :hcaptcha, [])[:sitekey]
  end

  def verify(token) do
    if enabled?() do
      res =
        HTTPClient.impl().post(
          @verify_endpoint,
          [{"content-type", "application/x-www-form-urlencoded"}],
          %{
            response: token,
            secret: secret()
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

  defp secret() do
    Application.get_env(:plausible, :hcaptcha, [])[:secret]
  end
end
