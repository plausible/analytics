defmodule PlausibleWeb.Api.CustomerSupport.Helpers do
  @moduledoc """
  Shared checks for the customer support automation API (`/api/cs/v1`).

  Every write goes through `run_action/6`:

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

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias PlausibleWeb.Api.Helpers, as: ApiHelpers

  @approval_fields ~w(conversation code approved_by)
  @audit_prefix "cs_api_"
  @daily_write_limit 30

  @doc """
  Loads the subject with `load`, runs `action` on it and records the audit
  entry `cs_api_{name}`. `action` returns `{:ok, audited_struct, change}`,
  where `change` is a JSON-safe map that is both stored and returned.

  Options: `:limit` (daily limit for this action name, in addition to the
  overall one).
  """
  def run_action(conn, params, name, load, action, opts \\ []) do
    with {:ok, approval} <- fetch_approval(params),
         :ok <- check_daily_limit(conn, @audit_prefix, @daily_write_limit),
         :ok <- maybe_check_action_limit(conn, name, opts[:limit]),
         {:ok, subject} <- load.(),
         {:ok, result} <- transact(conn, name, approval, fn -> action.(subject) end) do
      json(conn, %{result: result})
    else
      error -> respond_error(conn, error)
    end
  end

  def run_team_action(conn, params, name, action, opts \\ []) do
    run_action(conn, params, name, fn -> fetch_team(params["team_id"]) end, action, opts)
  end

  def run_site_action(conn, params, name, action, opts \\ []) do
    run_action(conn, params, name, fn -> fetch_site(params["site_id"]) end, action, opts)
  end

  def run_user_action(conn, params, name, action, opts \\ []) do
    run_action(conn, params, name, fn -> fetch_user(params["user_id"]) end, action, opts)
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

  def fetch_team(team_id) do
    with {:ok, id} <- parse_id(team_id),
         %Plausible.Teams.Team{} = team <- Plausible.Teams.get(id) do
      {:ok, Plausible.Teams.with_subscription(team)}
    else
      _ -> {:error, :not_found, "Team could not be found"}
    end
  end

  defp fetch_site(site_id) do
    with {:ok, id} <- parse_id(site_id),
         %Plausible.Site{} = site <- Repo.get(Plausible.Site, id) do
      {:ok, Repo.preload(site, :team)}
    else
      _ -> {:error, :not_found, "Site could not be found"}
    end
  end

  defp fetch_user(user_id) do
    with {:ok, id} <- parse_id(user_id),
         %Plausible.Auth.User{} = user <- Repo.get(Plausible.Auth.User, id) do
      {:ok, user}
    else
      _ -> {:error, :not_found, "User could not be found"}
    end
  end

  def fetch_suppression(email) when is_binary(email) do
    Repo.get_by(Plausible.EmailSuppression, email: String.trim(email))
  end

  def fetch_suppression(_), do: nil

  def parse_id(id) when is_integer(id), do: {:ok, id}

  def parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  def parse_id(_), do: :error

  def parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :guard, "Dates must be YYYY-MM-DD"}
    end
  end

  def parse_date(_), do: {:error, :guard, "Dates must be YYYY-MM-DD"}

  def guard(true, _message), do: :ok
  def guard(false, message), do: {:error, :guard, message}

  @max_note_line_length 500

  @doc """
  Checks a line for the team notes, the same for every endpoint that writes
  there: present, a single line, up to 500 characters.
  """
  def check_note_line(line, param) do
    with :ok <- guard(line != "", "Parameter `#{param}` is required"),
         :ok <- guard(not String.contains?(line, ["\n", "\r"]), "One line only") do
      guard(String.length(line) <= @max_note_line_length, "The line is too long")
    end
  end

  @doc "Appends one line to a team's notes."
  def append_note_line(nil, line), do: line
  def append_note_line("", line), do: line
  def append_note_line(notes, line), do: notes <> "\n" <> line

  defp maybe_check_action_limit(_conn, _name, nil), do: :ok

  defp maybe_check_action_limit(conn, name, limit) do
    check_daily_limit(conn, @audit_prefix <> name, limit)
  end

  defp check_daily_limit(conn, name_prefix, limit) do
    since = NaiveDateTime.add(NaiveDateTime.utc_now(), -24 * 3600)
    user_id = conn.assigns.current_user.id
    pattern = name_prefix <> "%"

    count =
      Repo.aggregate(
        from(e in Plausible.Audit.Entry,
          where: e.user_id == ^user_id and like(e.name, ^pattern) and e.datetime > ^since
        ),
        :count
      )

    if count < limit, do: :ok, else: {:error, :daily_limit}
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

  def respond_error(conn, {:error, :missing_approval}) do
    ApiHelpers.bad_request(
      conn,
      "Parameter `approval` with `conversation`, `code` and `approved_by` is required"
    )
  end

  def respond_error(conn, {:error, :not_found, message}), do: ApiHelpers.not_found(conn, message)

  def respond_error(conn, {:error, :daily_limit}) do
    ApiHelpers.too_many_requests(conn, "Daily limit for this action reached")
  end

  def respond_error(conn, {:error, :guard, message}), do: unprocessable(conn, message)

  def respond_error(conn, {:error, %Ecto.Changeset{} = changeset}) do
    unprocessable(conn, changeset_errors(changeset))
  end

  defp changeset_errors(changeset) do
    changeset
    |> Plausible.ChangesetHelpers.traverse_errors()
    |> Enum.map_join(", ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end

  defp unprocessable(conn, error) do
    conn
    |> put_status(422)
    |> json(%{error: error})
  end
end
