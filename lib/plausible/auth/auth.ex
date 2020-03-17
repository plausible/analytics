defmodule Plausible.Auth do
  use Plausible.Repo
  alias Plausible.Auth

  def create_user(name, email) do
    %Auth.User{}
    |> Auth.User.new(%{name: name, email: email})
    |> Repo.insert
  end

  def find_user_by(opts) do
    Repo.get_by(Auth.User, opts)
  end

  def user_completed_setup?(user) do
    query =
      from(
        e in Plausible.Event,
        join: s in Plausible.Site,
        on: s.domain == e.domain,
        join: sm in Plausible.Site.Membership,
        on: sm.site_id == s.id,
        join: u in Plausible.Auth.User,
        on: sm.user_id == u.id,
        where: u.id == ^user.id
      )

    Repo.exists?(query)
  end
end
