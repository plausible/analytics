defmodule PlausibleWeb.EmailView do
  use PlausibleWeb, :view

  def admin_email do
    Application.get_env(:plausible, :admin_email)
  end

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def base_domain() do
    PlausibleWeb.Endpoint.host()
  end

  def user_salutation(user) do
    if user.name do
      String.split(user.name) |> List.first()
    else
      ""
    end
  end

  def date_format(date) do
    Timex.format!(date, "{D} {Mshort} {YYYY}")
  end
end
