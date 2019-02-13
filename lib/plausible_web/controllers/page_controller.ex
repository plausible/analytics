defmodule PlausibleWeb.PageController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  def index(conn, _params) do
    if conn.assigns[:current_user] do
      user = conn.assigns[:current_user] |> Repo.preload(:sites)
      render(conn, "sites.html", sites: user.sites)
    else
      Plausible.Tracking.event(conn, "Landing: View Page")
      render(conn, "index.html", landing_nav: true)
    end
  end

  def feedback(conn, _params) do
    render(conn, "feedback.html")
  end

  def submit_feedback(conn, %{"text" => text, "email" => email}) do
    PlausibleWeb.Email.feedback(email, text)
      |> Plausible.Mailer.deliver_now
    render(conn, "feedback_thanks.html")
  end

  def privacy(conn, _params) do
    render(conn, "privacy.html")
  end

  def terms(conn, _params) do
    render(conn, "terms.html")
  end
end
