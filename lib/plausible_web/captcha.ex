defmodule PlausibleWeb.Captcha do
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
        HTTPoison.post!(@verify_endpoint, {:form, [{"response", token}, {"secret", secret()}]})

      json = Jason.decode!(res.body)
      json["success"]
    else
      true
    end
  end

  defp secret() do
    Application.get_env(:plausible, :hcaptcha, [])
    |> Keyword.fetch!(:secret)
  end
end
