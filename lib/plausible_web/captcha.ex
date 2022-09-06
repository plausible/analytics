defmodule PlausibleWeb.Captcha do
  alias Plausible.HTTPClient

  @verify_endpoint "https://hcaptcha.com/siteverify"

  def enabled? do
    !!sitekey()
  end

  def sitekey() do
    Application.get_env(:plausible, :hcaptcha, [])
    |> Keyword.fetch!(:sitekey)
  end

  def verify(token) do
    if enabled?() do
      res =
        HTTPClient.post(
          @verify_endpoint,
          [{"content-type", "application/x-www-form-urlencoded"}],
          %{
            response: token,
            secret: secret()
          }
        )

      case res do
        {:ok, %Finch.Response{status: 200, body: body}} ->
          json = Jason.decode!(body)
          json["success"]

        _ ->
          false
      end
    else
      true
    end
  end

  defp secret() do
    Application.get_env(:plausible, :hcaptcha, [])
    |> Keyword.fetch!(:secret)
  end
end
