defmodule PlausibleWeb.Api.CustomerSupport.Helpers do
  @moduledoc """
  Shared checks for the customer support automation API (`/api/cs/v1`).

  Every write goes through `run_action/5`:

    * it needs an `approval` (`conversation`, `code`, `approved_by`): the
      Help Scout thread and note that approved it. The caller (the broker on
      the support Mac) checks the note in Help Scout before calling; the
      server stores it with the change;
    * it counts against a per-user daily limit (30 writes in 24 hours, and a
      lower one for deletions), read from the audit log;
    * the action and its audit entry run in one transaction, so there is no
      change without an entry in the team's Audit tab.
  """
  use Plausible.Repo

  import Phoenix.Controller, only: [json: 2]

  alias PlausibleWeb.Api.Helpers, as: ApiHelpers

  @approval_fields ~w(conversation code approved_by)
  @audit_prefix "cs_api_"
  @daily_write_limit 30
  @daily_deletion_limit 5

  @doc """
  Loads the subject with `load`, runs `action` on it and records the audit
  entry `cs_api_{name}`. `action` returns `{:ok, audited_struct, change}`,
  where `change` is a JSON-safe map that is both stored and returned.

  A `name` ending in `_deleted` is a permanent deletion: it also counts
  against the daily deletion limit.
  """
  def run_action(conn, params, name, load, action) do
    with {:ok, approval} <- fetch_approval(params),
         :ok <- check_daily_limits(conn, String.ends_with?(name, "_deleted")),
         {:ok, subject} <- load.(),
         {:ok, result} <- transact(conn, name, approval, fn -> action.(subject) end) do
      json(conn, %{result: result})
    else
      error -> respond_error(conn, error)
    end
  end

  def run_team_action(conn, params, name, action) do
    run_action(conn, params, name, fn -> fetch_team(params["team_id"]) end, action)
  end

  @doc "Like `run_action/5` for a site; `params[\"domain\"]` must match the site."
  def run_site_action(conn, params, name, action) do
    run_action(conn, params, name, fn -> fetch_site(params) end, action)
  end

  @doc "Like `run_action/5` for a user; `params[\"email\"]` must match the user."
  def run_user_action(conn, params, name, action) do
    run_action(conn, params, name, fn -> fetch_user(params) end, action)
  end

  defp transact(conn, name, approval, action) do
    result =
      Repo.transaction(fn ->
        case action.() do
          {:ok, entity, change} ->
            audit!(conn, name, entity, approval, change)
            change

          error ->
            Repo.rollback(error)
        end
      end)

    with {:error, error} <- result, do: error
  end

  defp fetch_approval(%{"approval" => %{} = approval}) do
    approval = Map.take(approval, @approval_fields)

    if Enum.all?(@approval_fields, &(is_binary(approval[&1]) and approval[&1] != "")) do
      {:ok, approval}
    else
      {:error, :missing_approval}
    end
  end

  defp fetch_approval(_), do: {:error, :missing_approval}

  defp fetch_team(team_id) do
    with {:ok, id} <- parse_id(team_id),
         %Plausible.Teams.Team{} = team <- Plausible.Teams.get(id) do
      {:ok, Plausible.Teams.with_subscription(team)}
    else
      _ -> {:error, :not_found, "Team could not be found"}
    end
  end

  defp fetch_site(params) do
    with {:ok, id} <- parse_id(params["site_id"]),
         %Plausible.Site{} = site <- Repo.get(Plausible.Site, id) do
      with :ok <- guard(params["domain"] == site.domain, "The domain doesn't match the site"),
           do: {:ok, site}
    else
      _ -> {:error, :not_found, "Site could not be found"}
    end
  end

  defp fetch_user(params) do
    with {:ok, id} <- parse_id(params["user_id"]),
         %Plausible.Auth.User{} = user <- Repo.get(Plausible.Auth.User, id) do
      with :ok <- guard(email_matches?(user, params["email"]), "Email doesn't match the user"),
           do: {:ok, user}
    else
      _ -> {:error, :not_found, "User could not be found"}
    end
  end

  def email_matches?(user, email) when is_binary(email) do
    String.downcase(String.trim(email)) == String.downcase(user.email)
  end

  def email_matches?(_user, _email), do: false

  def parse_id(id) when is_integer(id), do: {:ok, id}

  def parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  def parse_id(_), do: :error

  def guard(true, _message), do: :ok
  def guard(false, message), do: {:error, :guard, message}

  defp check_daily_limits(conn, deletion?) do
    since = NaiveDateTime.add(NaiveDateTime.utc_now(), -24 * 3600)
    user_id = conn.assigns.current_user.id

    {writes, deletions} =
      Repo.one(
        from(e in Plausible.Audit.Entry,
          where:
            e.user_id == ^user_id and like(e.name, ^(@audit_prefix <> "%")) and
              e.datetime > ^since,
          select:
            {count(e.id), filter(count(e.id), like(e.name, ^(@audit_prefix <> "%_deleted")))}
        )
      )

    if writes < @daily_write_limit and (not deletion? or deletions < @daily_deletion_limit),
      do: :ok,
      else: {:error, :daily_limit}
  end

  defp audit!(conn, name, entity, approval, change) do
    (@audit_prefix <> name)
    |> Plausible.Audit.Entry.new(entity, %{
      team_id: team_id_of(entity),
      user_id: conn.assigns.current_user.id,
      actor_type: "user",
      meta: %{"approval" => approval}
    })
    |> Plausible.Audit.Entry.include_change(change)
    |> Plausible.Audit.Entry.persist!()
  end

  defp team_id_of(%Plausible.Teams.Team{id: id}), do: id
  defp team_id_of(%{team_id: id}) when is_integer(id), do: id
  defp team_id_of(_), do: 0

  defp respond_error(conn, {:error, :missing_approval}) do
    ApiHelpers.bad_request(
      conn,
      "Parameter `approval` with `conversation`, `code` and `approved_by` is required"
    )
  end

  defp respond_error(conn, {:error, :not_found, message}), do: ApiHelpers.not_found(conn, message)

  defp respond_error(conn, {:error, :daily_limit}) do
    ApiHelpers.too_many_requests(conn, "Daily limit for this action reached")
  end

  defp respond_error(conn, {:error, :guard, message}),
    do: ApiHelpers.unprocessable_entity(conn, message)

  defp respond_error(conn, {:error, %Ecto.Changeset{} = changeset}) do
    ApiHelpers.unprocessable_entity(conn, changeset_errors(changeset))
  end

  defp changeset_errors(changeset) do
    changeset
    |> Plausible.ChangesetHelpers.traverse_errors()
    |> Enum.map_join(", ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
