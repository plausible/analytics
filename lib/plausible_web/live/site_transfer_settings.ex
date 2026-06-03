defmodule PlausibleWeb.Live.SiteTransferSettings do
  @moduledoc """
  LiveView for the "Transfer site" tile in the site Danger Zone.

  Lets the site owner pick a destination (another team they own/admin or
  another Plausible account), validates the form interactively, and
  dispatches to the appropriate transfer action.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Teams
  alias PlausibleWeb.Live.SiteTransferSettings.Form
  alias PlausibleWeb.Router.Helpers, as: Routes

  def mount(_params, %{"domain" => domain}, socket) do
    user = socket.assigns.current_user

    site =
      Plausible.Sites.get_for_user!(user, domain, roles: [:owner, :admin, :super_admin])

    teams = Teams.Users.teams(user, roles: [:owner, :admin])

    team_options =
      user
      |> Teams.Users.teams(roles: [:owner, :admin])
      |> Enum.reject(&(&1.id == site.team_id || not &1.setup_complete))
      |> Enum.map(&{&1.name, &1.identifier})

    show_teams? = team_options != []

    show_my_team? =
      not is_nil(socket.assigns[:my_team]) and socket.assigns.my_team.id != site.team_id

    my_team_notice =
      cond do
        not is_nil(socket.assigns[:my_team]) and socket.assigns.my_team.id == site.team_id ->
          "The site is already in your personal sites."

        is_nil(socket.assigns[:my_team]) ->
          "You don't have an active subscription."

        true ->
          nil
      end

    initial_destination =
      cond do
        show_teams? -> :team
        show_my_team? -> :my_team
        true -> :account
      end

    socket =
      socket
      |> assign(
        site: site,
        teams: teams,
        team_options: team_options,
        show_teams?: show_teams?,
        show_my_team?: show_my_team?,
        my_team_notice: my_team_notice
      )
      |> assign_form(%{"destination" => initial_destination})

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.flash_messages flash={@flash} />

      <.tile docs="transfer-ownership">
        <:title>Transfer site</:title>
        <:subtitle>Move this site to another team or Plausible account.</:subtitle>

        <.form
          :let={f}
          for={@form}
          id="site-transfer-form"
          phx-change="validate"
          phx-submit="save"
        >
          <fieldset class="max-w-lg flex flex-col gap-y-4">
            <.label>Destination</.label>

            <div class="flex flex-col">
              <div class={not @show_teams? && "opacity-40 cursor-not-allowed"}>
                <.input
                  type="radio"
                  id="destination-team"
                  name={f[:destination].name}
                  value={:team}
                  checked={f[:destination].value == :team and @show_teams?}
                  disabled={not @show_teams?}
                  label="Team"
                />
              </div>
              <div
                :if={f[:destination].value == :team and @show_teams?}
                class="ml-7 mt-1 flex flex-col gap-y-2"
              >
                <p class="text-sm text-gray-500 dark:text-gray-400 text-pretty">
                  The site will immediately move to the selected team. Billing does not transfer.
                </p>
                <.input
                  type="select"
                  field={f[:team_identifier]}
                  options={@team_options}
                  prompt="Select a team"
                  mt?={false}
                />
              </div>
              <p
                :if={not @show_teams?}
                class="ml-7 mt-1 text-sm text-gray-500/60 dark:text-gray-400/60 text-pretty"
              >
                You aren't a member of any other teams or you lack privileges for transfer.
              </p>
            </div>

            <div class="flex flex-col">
              <.input
                type="radio"
                id="destination-account"
                name={f[:destination].name}
                value={:account}
                checked={f[:destination].value == :account}
                label="Another Plausible account"
              />
              <div
                :if={f[:destination].value == :account}
                class="ml-7 mt-1 flex flex-col gap-y-2"
              >
                <p class="text-sm text-gray-500 dark:text-gray-400 text-pretty">
                  The recipient will receive an email and have 48 hours to accept the transfer. You'll keep Guest Editor access by default.
                </p>
                <.input
                  type="email"
                  field={f[:email]}
                  label="Email address"
                  placeholder="example@email.com"
                  mt?={false}
                />
              </div>
            </div>

            <div class="flex flex-col">
              <div class={not @show_my_team? && "opacity-40 cursor-not-allowed"}>
                <.input
                  type="radio"
                  id="destination-my_team"
                  name={f[:destination].name}
                  value={:my_team}
                  checked={f[:destination].value == :my_team}
                  disabled={not @show_my_team?}
                  label="My personal sites"
                />
                <div class="ml-7">
                  <.input
                    :if={@show_my_team?}
                    type="hidden"
                    field={f[:my_team_available]}
                    value={true}
                    mt?={false}
                  />
                </div>
              </div>
              <p
                :if={@my_team_notice}
                class="ml-7 mt-1 text-sm text-gray-500/60 dark:text-gray-400/60 text-pretty"
              >
                {@my_team_notice}
              </p>
            </div>
          </fieldset>

          <.button
            type="submit"
            theme="danger"
            phx-disable-with="Transferring..."
          >
            {submit_label(f[:destination].value)}
          </.button>
        </.form>
      </.tile>
    </div>
    """
  end

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign_form(socket, params)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    changeset = Form.changeset(params)

    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, %Form{destination: :team, team_identifier: identifier}} ->
        team = Enum.find(socket.assigns.teams, &(&1.identifier == identifier))
        do_change_team(socket, team, params)

      {:ok, %Form{destination: :my_team}} ->
        do_change_team(socket, socket.assigns[:my_team], params)

      {:ok, %Form{destination: :account, email: email}} ->
        do_transfer_ownership(socket, email, params)

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :form))}
    end
  end

  defp do_change_team(socket, destination_team, params) do
    if destination_team do
      my_team? =
        not is_nil(socket.assigns[:my_team]) and socket.assigns.my_team.id == destination_team.id

      user = socket.assigns.current_user
      site = socket.assigns.site

      error_field = if(my_team?, do: :my_team_available, else: :team_identifier)

      case Teams.Sites.Transfer.change_team(site, user, destination_team) do
        :ok ->
          {:noreply,
           socket
           |> put_flash(:success, "Site team was changed")
           |> redirect(to: Routes.site_path(socket, :index, __team: destination_team.identifier))}

        {:error, reason} ->
          {:noreply,
           assign_form(socket, params,
             action: :insert,
             field_errors: [{error_field, change_team_error_message(reason, my_team?)}]
           )}
      end
    else
      {:noreply,
       assign_form(socket, params,
         action: :insert,
         field_errors: [{:team_identifier, "Please select a team"}]
       )}
    end
  end

  defp do_transfer_ownership(socket, email, params) do
    user = socket.assigns.current_user
    site = socket.assigns.site

    case Teams.Invitations.InviteToSite.invite(site, user, email, :owner) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> put_flash(:success, "Site transfer request has been sent to #{email}")
         |> redirect(to: Routes.site_path(socket, :settings_people, site.domain))}

      {:error, %Ecto.Changeset{} = changeset} ->
        message =
          case Plausible.ChangesetHelpers.traverse_errors(changeset) do
            %{invitation: ["already sent" | _]} -> "Invitation has already been sent"
            _ -> "Site transfer request to #{email} has failed"
          end

        {:noreply,
         assign_form(socket, params,
           action: :insert,
           field_errors: [{:email, message}]
         )}
    end
  end

  defp assign_form(socket, params, opts \\ []) do
    changeset = Form.changeset(params)

    changeset =
      Enum.reduce(Keyword.get(opts, :field_errors, []), changeset, fn {field, message}, cs ->
        Ecto.Changeset.add_error(cs, field, message)
      end)

    changeset =
      case opts[:action] do
        nil -> changeset
        action -> Map.put(changeset, :action, action)
      end

    assign(socket, form: to_form(changeset, as: :form))
  end

  defp submit_label(:team), do: "Move site"
  defp submit_label(:my_team), do: "Move site"
  defp submit_label(_), do: "Send transfer request"

  defp change_team_error_message(:no_plan, false = _my_team?) do
    "This team doesn't have a subscription. Please start a subscription for the team first and then try moving the site again."
  end

  defp change_team_error_message(:no_plan, true = _my_team?) do
    "You don't have a subscription. Please start a subscription first and then try moving the site again."
  end

  defp change_team_error_message({:over_plan_limits, _}, false = _my_team?) do
    "This site's usage exceeds the destination team's subscription limits. Upgrade the team's subscription to continue."
  end

  defp change_team_error_message({:over_plan_limits, _}, true = _my_team?) do
    "This site's usage exceeds your subscription limits. Upgrade your subscription to continue."
  end

  defp change_team_error_message(_, false = _my_team?) do
    "Sorry, this team cannot be used."
  end

  defp change_team_error_message(_, true = _my_team?) do
    "Sorry, My personal sites cannot be used."
  end
end
