defmodule Plausible.Auth do
  use Plausible.Repo
  alias Plausible.Auth

  def issue_email_verification(user) do
    Repo.update_all(from(c in "email_verification_codes", where: c.user_id == ^user.id),
      set: [user_id: nil]
    )

    code =
      Repo.one(
        from(c in "email_verification_codes", where: is_nil(c.user_id), select: c.code, limit: 1)
      )

    Repo.update_all(from(c in "email_verification_codes", where: c.code == ^code),
      set: [user_id: user.id, issued_at: Timex.now()]
    )

    code
  end

  defp is_expired?(activation_code_issued) do
    Timex.before?(activation_code_issued, Timex.shift(Timex.now(), hours: -4))
  end

  def verify_email(user, code) do
    found_code =
      Repo.one(
        from c in "email_verification_codes",
          where: c.user_id == ^user.id,
          where: c.code == ^code,
          select: %{code: c.code, issued: c.issued_at}
      )

    cond do
      is_nil(found_code) ->
        {:error, :incorrect}

      is_expired?(found_code[:issued]) ->
        {:error, :expired}

      true ->
        {:ok, _} =
          Ecto.Multi.new()
          |> Ecto.Multi.update(
            :user,
            Plausible.Auth.User.changeset(user, %{email_verified: true})
          )
          |> Ecto.Multi.update_all(
            :codes,
            from(c in "email_verification_codes", where: c.user_id == ^user.id),
            set: [user_id: nil]
          )
          |> Repo.transaction()

        :ok
    end
  end

  def create_user(name, email, pwd) do
    Auth.User.new(%{name: name, email: email, password: pwd, password_confirmation: pwd})
    |> Repo.insert()
  end

  def find_user_by(opts) do
    Repo.get_by(Auth.User, opts)
  end

  def has_active_sites?(user, roles \\ [:owner, :admin, :viewer]) do
    sites =
      Repo.all(
        from u in Plausible.Auth.User,
          where: u.id == ^user.id,
          join: sm in Plausible.Site.Membership,
          on: sm.user_id == u.id,
          where: sm.role in ^roles,
          join: s in Plausible.Site,
          on: s.id == sm.site_id,
          select: s
      )

    Enum.any?(sites, &Plausible.Sites.has_stats?/1)
  end

  def delete_user(user) do
    Repo.transaction(fn ->
      user =
        user
        |> Repo.preload(site_memberships: :site)

      for membership <- user.site_memberships do
        Repo.delete!(membership)

        if membership.role == :owner do
          Plausible.Site.Removal.run(membership.site.domain)
        end
      end

      Repo.delete!(user)
    end)
  end

  def user_owns_sites?(user) do
    Repo.exists?(
      from(s in Plausible.Site,
        join: sm in Plausible.Site.Membership,
        on: sm.site_id == s.id,
        where: sm.user_id == ^user.id,
        where: sm.role == :owner
      )
    )
  end

  def is_super_admin?(nil), do: false

  def is_super_admin?(user_id) do
    user_id in Application.get_env(:plausible, :super_admin_user_ids)
  end

  def enterprise?(nil), do: false

  def enterprise?(%Plausible.Auth.User{} = user) do
    user = Repo.preload(user, :enterprise_plan)
    user.enterprise_plan != nil
  end
end
