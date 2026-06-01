defmodule PlausibleWeb.Live.SiteTransferSettings do
  @moduledoc """
  LiveView for the "Transfer site" tile in the site Danger Zone.

  Lets the site owner pick a destination (another team they own/admin or
  another Plausible account), validates the form interactively, and
  dispatches to the appropriate transfer action.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Teams
  alias PlausibleWeb.Router.Helpers, as: Routes

  defmodule Form do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :destination, Ecto.Enum, values: [:team, :account]
      field :team_identifier, :string
      field :email, :string
    end

    def changeset(params) do
      %__MODULE__{}
      |> cast(params, [:destination, :team_identifier, :email])
      |> validate_required(:destination)
      |> validate_destination_fields()
    end

    defp validate_destination_fields(changeset) do
      case get_field(changeset, :destination) do
        :team ->
          validate_required(changeset, :team_identifier, message: "Please select a team")

        :account ->
          validate_required(changeset, :email, message: "Please enter an email address")
      end
    end
  end

  def mount(_params, %{"domain" => domain}, socket) do
    user = socket.assigns.current_user

    site =
      Plausible.Sites.get_for_user!(user, domain, roles: [:owner, :admin, :super_admin])

    transferable_teams =
      user
      |> Teams.Users.teams(roles: [:owner, :admin])
      |> Enum.reject(&(&1.id == site.team_id))
      |> Enum.map(&{&1.name, &1.identifier})

    show_team? = transferable_teams != []
    initial_destination = if show_team?, do: :team, else: :account

    socket =
      socket
      |> assign(
        site: site,
        transferable_teams: transferable_teams,
        show_team?: show_team?
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
          novalidate
        >
          <fieldset class="max-w-lg flex flex-col gap-y-4">
            <.label>Destination</.label>

            <div class="flex flex-col">
              <div class={not @show_team? && "opacity-40 cursor-not-allowed"}>
                <.input
                  type="radio"
                  id="destination-team"
                  name={f[:destination].name}
                  value={:team}
                  checked={f[:destination].value == :team and @show_team?}
                  disabled={not @show_team?}
                  label="Team"
                />
              </div>
              <div
                :if={f[:destination].value == :team and @show_team?}
                class="ml-7 mt-1 flex flex-col gap-y-2"
              >
                <p class="text-sm text-gray-500 dark:text-gray-400 text-pretty">
                  The site will immediately move to the selected team. Billing does not transfer.
                </p>
                <.input
                  type="select"
                  field={f[:team_identifier]}
                  options={@transferable_teams}
                  prompt="Select a team"
                  mt?={false}
                />
              </div>
              <p
                :if={not @show_team?}
                class="ml-7 mt-1 text-sm text-gray-500/60 dark:text-gray-400/60 text-pretty"
              >
                You aren't a member of any other teams.
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
        do_change_team(socket, identifier, params)

      {:ok, %Form{destination: :account, email: email}} ->
        do_transfer_ownership(socket, email, params)

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :form))}
    end
  end

  defp do_change_team(socket, identifier, params) do
    user = socket.assigns.current_user
    site = socket.assigns.site

    destination_team =
      Repo.one(Teams.Users.teams_query(user, roles: [:admin, :owner], identifier: identifier))

    if destination_team do
      case Teams.Sites.Transfer.change_team(site, user, destination_team) do
        :ok ->
          {:noreply,
           socket
           |> put_flash(:success, "Site team was changed")
           |> redirect(to: Routes.site_path(socket, :index, __team: identifier))}

        {:error, reason} ->
          {:noreply,
           assign_form(socket, params,
             action: :insert,
             field_errors: [{:team_identifier, change_team_error_message(reason)}]
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
  defp submit_label(_), do: "Send transfer request"

  defp change_team_error_message(:no_plan) do
    "This team doesn't have a subscription. Please start a subscription for the team first and then try moving the site again."
  end

  defp change_team_error_message({:over_plan_limits, _}) do
    "This site's usage exceeds the destination team's subscription limits. Upgrade the team's subscription to continue."
  end

  defp change_team_error_message(_) do
    "Sorry, this team cannot be used"
  end
end
