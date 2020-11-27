defmodule Plausible.Auth do
  use Plausible.Repo
  alias Plausible.Auth
  alias Plausible.Stats.Clickhouse, as: Stats

  def issue_activation_code(user) do
    Repo.update_all(from(c in "activation_pins", where: c.user_id == ^user.id), [set: [user_id: nil]])

    pin = Repo.one(from(c in "activation_pins", where: is_nil(c.user_id), select: c.pin, limit: 1))

    Repo.update_all(from(c in "activation_pins", where: c.pin == ^pin), [set: [user_id: user.id, issued_at: Timex.now()]])

    pin
  end

  def create_user(name, email) do
    %Auth.User{}
    |> Auth.User.new(%{name: name, email: email})
    |> Repo.insert()
  end

  def find_user_by(opts) do
    Repo.get_by(Auth.User, opts)
  end

  def user_completed_setup?(user) do
    domains =
      Repo.all(
        from u in Plausible.Auth.User,
          where: u.id == ^user.id,
          join: sm in Plausible.Site.Membership,
          on: sm.user_id == u.id,
          join: s in Plausible.Site,
          on: s.id == sm.site_id,
          select: s.domain
      )

    Stats.has_pageviews?(domains)
  end
end
