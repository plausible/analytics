defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  import PlausibleWeb.Live.Components.Team

  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Management.Layout
  alias PlausibleWeb.Flows
  alias PlausibleWeb.Router.Helpers, as: Routes

  @invite_roles [:owner, :admin, :editor, :billing, :viewer]
  @roles_cast_map Enum.into(@invite_roles, %{}, fn role -> {to_string(role), role} end)

  def mount(params, _session, socket) do
    current_user = socket.assigns.current_user

    flow = params["flow"]
    domain = params["domain"]
    onboarding? = flow == Flows.register()

    current_team = current_team(socket, onboarding?)

    socket =
      assign(socket,
        flow: flow,
        domain: domain,
        onboarding?: onboarding?,
        return_to: return_to(socket, params["return_to"]),
        heading: "Create a team",
        subtitle: "Share access and collaborate with others.",
        current_step: "Create team"
      )

    socket =
      case current_team do
        %Teams.Team{setup_complete: true} ->
          if onboarding? do
            redirect(socket, to: next_path(socket, domain, flow))
          else
            socket
            |> put_flash(:success, "Your team is now created")
            |> redirect(to: Routes.settings_path(socket, :team_general))
          end

        %Teams.Team{} ->
          team =
            current_team
            |> Teams.Team.name_changeset(%{
              name: default_team_name(current_user, domain, onboarding?)
            })
            |> Repo.update!()

          {:ok, my_role} = Teams.Memberships.team_role(team, current_user)

          assign(socket,
            team_name_form: team |> Teams.Team.name_changeset(%{}) |> to_form(),
            current_team: team,
            my_role: my_role,
            team_layout: Layout.init(team),
            team_members_limit: Teams.Billing.team_member_limit(team),
            invite_rows: [new_invite_row()]
          )

        _ ->
          socket
          |> put_flash(:error, "You cannot create any team just yet")
          |> redirect(to: Routes.site_path(socket, :index))
      end

    {:ok, socket}
  end

  def render(assigns) do
    assigns =
      assign(assigns,
        locked?: Teams.Billing.solo?(assigns.current_team),
        at_limit?: at_limit?(assigns.team_layout, assigns.team_members_limit, pending(assigns))
      )

    ~H"""
    <div class="relative w-full max-w-md mx-auto mt-10 pb-16 px-4 dark:text-gray-300">
      <.flash_messages flash={@flash} />

      <PlausibleWeb.Components.Billing.feature_gate
        current_user={@current_user}
        current_team={@current_team}
        locked?={@locked?}
      >
        <.form
          :let={f}
          for={@team_name_form}
          id="team-setup-form"
          phx-change="update-form"
          phx-submit="create-team"
          class="flex flex-col gap-y-8"
        >
          <PlausibleWeb.Components.Billing.Notice.limit_exceeded
            :if={@team_members_limit != 0 and @at_limit?}
            current_user={@current_user}
            current_team={@current_team}
            limit={@team_members_limit}
            resource="members"
          />

          <.input
            type="text"
            field={f[:name]}
            label="Team name"
            placeholder={"#{@current_user.name}'s team"}
            autofocus={not @locked?}
            width="w-full"
            mt?={false}
            phx-debounce="500"
          />

          <div>
            <div class="flex items-center justify-between mb-1.5">
              <.label for="invite-email-0" class="mb-0">Invite members (optional)</.label>
              <button
                type="button"
                id="add-invite-row"
                phx-click="add-invite-row"
                disabled={@at_limit?}
                aria-label="Add another member"
                class="text-gray-500 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100 disabled:text-gray-300 dark:disabled:text-gray-600 transition-colors duration-150"
              >
                <Heroicons.plus mini class="size-4" />
              </button>
            </div>

            <div class="flex flex-col gap-y-2">
              <div
                :for={{row, idx} <- Enum.with_index(@invite_rows)}
                class="flex gap-x-2 items-start"
              >
                <div class="flex-1">
                  <.input
                    type="email"
                    name="invites[]"
                    id={"invite-email-#{idx}"}
                    value={row.email}
                    placeholder="jane@example.com"
                    errors={if row.error, do: [row.error], else: []}
                    mt?={false}
                    phx-debounce="500"
                  />
                </div>
                <.dropdown id={"invite-role-#{idx}"}>
                  <:button class="role min-w-24 inline-flex items-center justify-between gap-x-2 font-medium rounded-md px-3 py-2.5 text-sm border border-gray-300 dark:border-gray-750 text-gray-800 dark:text-gray-100 dark:bg-gray-750 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate shadow-xs hover:shadow-sm transition-all duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">
                    {role_label(row.role)}
                    <Heroicons.chevron_down mini class="size-4 mt-0.5" />
                  </:button>
                  <:menu class="dropdown-items max-w-60">
                    <.role_item
                      :for={role <- invite_roles()}
                      id={"invite-role-#{idx}-#{role}"}
                      role={role}
                      disabled={role == :owner and @my_role != :owner}
                      phx-click="switch-role"
                      phx-value-index={idx}
                    >
                      {role_description(role)}
                    </.role_item>
                  </:menu>
                </.dropdown>
              </div>
            </div>

            <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
              We'll send them an email invitation.
              <.styled_link href={roles_docs_link()}>Learn about roles</.styled_link>
            </p>
          </div>

          <div :if={not @onboarding?}>
            <.label class="mb-0">Team members</.label>
            <.member_list layout={@team_layout} my_role={@my_role} current_user={@current_user} />
          </div>

          <div class="flex justify-end items-center gap-x-2">
            <.button_link
              :if={@onboarding?}
              theme="ghost"
              href={next_path(@socket, @domain, @flow)}
              mt?={false}
            >
              Skip
            </.button_link>
            <.button_link :if={not @onboarding?} theme="ghost" href={@return_to} mt?={false}>
              Cancel
            </.button_link>
            <.button type="submit" mt?={false} disabled={@at_limit?}>
              Create team
            </.button>
          </div>
        </.form>
      </PlausibleWeb.Components.Billing.feature_gate>
    </div>
    """
  end

  def handle_event("update-form", params, socket) do
    socket =
      socket
      |> persist_team_name(get_in(params, ["team", "name"]))
      |> assign(invite_rows: rows_from_params(params, socket.assigns.invite_rows))

    {:noreply, socket}
  end

  def handle_event("add-invite-row", _params, socket) do
    {:noreply, assign(socket, invite_rows: socket.assigns.invite_rows ++ [new_invite_row()])}
  end

  def handle_event("switch-role", %{"role" => role, "index" => index}, socket) do
    role = Map.fetch!(@roles_cast_map, role)

    rows =
      List.update_at(
        socket.assigns.invite_rows,
        String.to_integer(index),
        &%{&1 | role: role}
      )

    {:noreply, assign(socket, invite_rows: rows)}
  end

  def handle_event("update-role", %{"email" => email, "role" => role}, socket) do
    layout =
      Layout.update_role(
        socket.assigns.team_layout,
        email,
        Map.fetch!(@roles_cast_map, role)
      )

    socket =
      socket
      |> assign(team_layout: layout)
      |> push_event("js-exec", %{
        to: "#member-row-#{:erlang.phash2(email)}",
        attr: "data-role-changed"
      })

    {:noreply, socket}
  end

  def handle_event("remove-member", %{"email" => email}, socket) do
    layout = socket.assigns.team_layout

    socket =
      case Layout.verify_removable(layout, email) do
        :ok -> assign(socket, team_layout: Layout.schedule_delete(layout, email))
        {:error, message} -> put_live_flash(socket, :error, message)
      end

    {:noreply, socket}
  end

  def handle_event("create-team", params, socket) do
    socket = persist_team_name(socket, get_in(params, ["team", "name"]))

    rows =
      params
      |> rows_from_params(socket.assigns.invite_rows)
      |> validate_rows(socket.assigns.team_layout)

    socket = assign(socket, invite_rows: rows)

    if socket.assigns.team_name_form.source.valid? and Enum.all?(rows, &is_nil(&1.error)) do
      {:noreply, create_team(socket, rows)}
    else
      {:noreply, socket}
    end
  end

  defp create_team(socket, rows) do
    %{current_user: current_user, current_team: current_team} = socket.assigns

    layout =
      rows
      |> Enum.reject(&(&1.email == ""))
      |> Enum.reduce(socket.assigns.team_layout, &invite/2)

    result =
      Layout.persist(layout, %{current_user: current_user, current_team: current_team})

    case result do
      {:ok, _} ->
        socket
        |> put_flash(:success, "Your team is now created")
        |> redirect(to: created_path(socket))

      {:error, error} ->
        put_live_flash(socket, :error, persist_error_message(error))
    end
  end

  # An entry queued for removal is brought back with the picked role, rather
  # than invited anew.
  defp invite(row, layout) do
    if removed?(layout, row.email) do
      Layout.update_role(layout, row.email, row.role)
    else
      Layout.schedule_send(layout, row.email, row.role)
    end
  end

  defp persist_team_name(socket, name) when is_binary(name) do
    if name == socket.assigns.current_team.name do
      socket
    else
      update_team_name(socket, name)
    end
  end

  defp persist_team_name(socket, _name), do: socket

  defp update_team_name(socket, name) do
    changeset = Teams.Team.name_changeset(socket.assigns.current_team, %{name: name})

    case Repo.update(changeset) do
      {:ok, team} ->
        assign(socket, team_name_form: to_form(changeset), current_team: team)

      {:error, changeset} ->
        assign(socket, team_name_form: to_form(changeset))
    end
  end

  defp rows_from_params(params, current_rows) do
    case params["invites"] do
      emails when is_list(emails) ->
        emails
        |> Enum.with_index()
        |> Enum.map(fn {email, idx} ->
          %{new_invite_row() | email: email, role: role_at(current_rows, idx)}
        end)

      _ ->
        current_rows
    end
  end

  defp role_at(rows, idx) do
    case Enum.at(rows, idx) do
      %{role: role} -> role
      nil -> :viewer
    end
  end

  defp validate_rows(rows, layout) do
    {rows, _seen} =
      Enum.map_reduce(rows, MapSet.new(), fn row, seen ->
        email = String.trim(row.email)

        error =
          cond do
            email == "" -> nil
            not valid_email?(email) -> "Please enter a valid email address"
            MapSet.member?(seen, email) -> "This email is already added"
            in_team?(layout, email) -> "This email is already in your team"
            true -> nil
          end

        {%{row | email: email, error: error}, MapSet.put(seen, email)}
      end)

    rows
  end

  defp valid_email?(email) do
    String.contains?(email, "@") and String.contains?(email, ".")
  end

  defp in_team?(layout, email), do: Map.has_key?(layout, email) and not removed?(layout, email)

  defp removed?(layout, email) do
    match?(%{queued_op: :delete}, Map.get(layout, email))
  end

  defp new_invite_row, do: %{email: "", role: :viewer, error: nil}

  defp pending(assigns) do
    Enum.count(assigns.invite_rows, &(String.trim(&1.email) != ""))
  end

  # Onboarding users who skipped adding a site have no team yet, as one is
  # implicitly created along with the first site.
  defp current_team(socket, onboarding?) do
    case socket.assigns.current_team do
      nil when onboarding? ->
        case Teams.get_or_create(socket.assigns.current_user) do
          {:ok, team} -> team
          {:error, _} -> nil
        end

      current_team ->
        current_team
    end
  end

  # Only local paths are accepted, so that the Cancel link can't be pointed
  # elsewhere via the query string.
  defp return_to(socket, path) do
    if is_binary(path) and String.starts_with?(path, "/") and not String.starts_with?(path, "//") do
      path
    else
      Routes.site_path(socket, :index)
    end
  end

  defp next_path(socket, domain, flow, params \\ [])

  defp next_path(socket, domain, flow, params) when is_binary(domain) and domain != "" do
    Routes.site_path(socket, :installation, domain, [flow: flow] ++ params)
  end

  defp next_path(socket, _domain, _flow, params), do: Routes.site_path(socket, :index, params)

  # The team just created has to become the current one, which the plug picks up
  # from the query string on the next request.
  defp created_path(socket) do
    %{current_team: team, domain: domain, flow: flow} = socket.assigns

    if socket.assigns.onboarding? do
      next_path(socket, domain, flow, __team: team.identifier)
    else
      Routes.settings_path(socket, :team_general, __team: team.identifier)
    end
  end

  defp default_team_name(user, domain, true) when is_binary(domain) do
    team_name_from_domain(domain) || personal_team_name(user)
  end

  defp default_team_name(user, _domain, _onboarding?), do: personal_team_name(user)

  defp personal_team_name(user), do: "#{user.name}'s team"

  defp team_name_from_domain(domain) do
    with registrable when is_binary(registrable) <- PublicSuffix.registrable_domain(domain),
         [label | _] <- String.split(registrable, "."),
         name when name != "" <-
           label |> String.split("-", trim: true) |> Enum.map_join(" ", &String.capitalize/1) do
      name
    else
      _ -> nil
    end
  end

  defp invite_roles, do: @invite_roles

  defp roles_docs_link, do: "https://plausible.io/docs/users-roles"

  defp role_label(role), do: role |> Atom.to_string() |> String.capitalize()

  defp role_description(:owner), do: "Manage the team without restrictions"
  defp role_description(:admin), do: "Manage all team settings"
  defp role_description(:editor), do: "Create and view new sites"
  defp role_description(:billing), do: "Manage subscription"
  defp role_description(:viewer), do: "View all sites under your team"
end
