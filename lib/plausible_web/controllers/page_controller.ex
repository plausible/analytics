defmodule PlausibleWeb.PageController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  @demo_referrers [
    {"indiehackers.com", 56},
    {"Github", 23},
    {"Twitter", 17},
    {"Reddit", 8},
    {"Google", 6},
    {"DuckDuckGo", 4},
    {"Bing", 2},
  ]

   @demo_pages [
     {"/", 140},
     {"/plausible.io", 63},
     {"/blog", 41},
     {"/register", 13},
     {"/login", 7},
     {"/blog/google-analytics-and-privacy", 4},
     {"/blog/launching-plausible", 2}
  ]

  def index(conn, _params) do
    if conn.assigns[:current_user] do
      user = conn.assigns[:current_user] |> Repo.preload(:sites)
      render(conn, "sites.html", sites: user.sites)
    else
      render(conn, "index.html", demo_referrers: @demo_referrers, demo_pages: @demo_pages, landing_nav: true)
    end
  end

  defmodule Token do
    use Joken.Config
  end

  defp sign_token!(user) do
    claims = %{
      id: user.id,
      email: user.email,
      name: user.name,
    }

    signer = Joken.Signer.create("HS256", "4d1d2ae6-4595-4d0b-b98a-8ca5b1f2095a")
    {:ok, token, _} = Token.generate_and_sign(claims, signer)
    token
  end

  def feedback(conn, _params) do
    if conn.assigns[:current_user] do
      token = sign_token!(conn.assigns[:current_user])
      redirect(conn, external: "https://feedback.plausible.io/sso/#{token}")
    else
      redirect(conn, external: "https://feedback.plausible.io")
    end
  end

  def roadmap(conn, _params) do
    if conn.assigns[:current_user] do
      token = sign_token!(conn.assigns[:current_user])
      redirect(conn, external: "https://feedback.plausible.io/sso/#{token}?returnUrl=https://feedback.plausible.io/roadmap")
    else
      redirect(conn, external: "https://feedback.plausible.io/roadmap")
    end
  end

  def contact_form(conn, _params) do
    render(conn, "contact_form.html")
  end

  def submit_contact_form(conn, %{"text" => text, "email" => email}) do
    PlausibleWeb.Email.feedback(email, text) |> Plausible.Mailer.deliver_now
    render(conn, "contact_thanks.html")
  end

  def privacy(conn, _params) do
    render(conn, "privacy.html")
  end

  def data_policy(conn, _params) do
    render(conn, "data_policy.html")
  end

  def terms(conn, _params) do
    render(conn, "terms.html")
  end
end
