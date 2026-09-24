defmodule PlausibleWeb.Live.OAuthAuthorize do
  @moduledoc """
  Consent screen for an OAuth authorization request.

  The client's metadata document is fetched once, by the controller that renders
  this view, and the context it yields travels into the socket as signed session
  data. The approve/deny decision is then taken against that context rather than
  against a second fetch of a document the client can change in between, so what
  the grant records is what the user was shown - a client cannot serve one
  `client_name` to the screen and another to the click.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Auth
  alias Plausible.OAuth
  alias PlausibleWeb.OAuth.AuthorizationResponse
  alias PlausibleWeb.OAuth.GrantableTeams

  @rate_limited_message "Too many authorization requests. Wait a minute before trying again."

  def mount(_params, %{"ctx" => ctx}, socket) do
    {:ok,
     assign(socket,
       ctx: ctx,
       grantable_teams: GrantableTeams.list(socket.assigns),
       selected_team: GrantableTeams.resolve(socket.assigns, ctx.team)
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-y-6">
      <.flash_messages flash={@flash} />

      <p
        class="text-sm text-gray-600 dark:text-gray-400 text-center"
        data-test-id="client-identity"
      >
        <span class="font-semibold break-all">{@ctx.client_name || @ctx.client_id}</span>
        wants to connect to your Plausible account
        <span
          :if={@ctx.client_name}
          class="block text-xs text-gray-500 dark:text-gray-500 mt-1 break-all"
        >
          Client ID: {@ctx.client_id}
        </span>
      </p>

      <div class="rounded-md bg-gray-50 dark:bg-gray-900 p-4">
        <p class="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-2">
          This will allow the application to:
        </p>
        <ul class="list-disc list-inside text-sm text-gray-600 dark:text-gray-400 space-y-1">
          <li :for={scope <- @ctx.scopes}>{Plausible.Auth.Scopes.description(scope)}</li>
        </ul>
      </div>

      <div class="flex flex-col gap-y-4">
        <div class="flex flex-col gap-y-2" data-test-id="grant-team">
          <%= if match?([_, _ | _], @grantable_teams) do %>
            <form phx-change="select_team" phx-submit="select_team">
              <label
                for="team"
                class="text-sm font-semibold text-gray-800 dark:text-gray-200"
              >
                Grant access to team
              </label>
              <select
                id="team"
                name="team"
                class="block w-full rounded-md border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100 text-sm"
              >
                <option
                  :for={team <- @grantable_teams}
                  value={team.identifier}
                  selected={team.identifier == @selected_team.identifier}
                >
                  {team.name}
                </option>
              </select>
            </form>
          <% else %>
            <p class="text-sm font-semibold text-gray-800 dark:text-gray-200">
              Grant access to team
            </p>
            <p class="text-sm text-gray-600 dark:text-gray-400 break-all">
              {@selected_team.name}
            </p>
          <% end %>
          <p class="text-xs text-gray-500 dark:text-gray-500">
            The connection will only be able to access the data of the selected team.
          </p>
        </div>

        <div class="flex gap-x-3 mt-2">
          <button
            type="button"
            phx-click="deny"
            class="btn-base btn-md btn-theme-secondary flex-1"
          >
            Deny
          </button>
          <button
            type="button"
            phx-click="approve"
            phx-disable-with="Approving..."
            class="btn-base btn-md btn-theme-primary flex-1"
          >
            Approve
          </button>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("select_team", %{"team" => identifier}, socket) do
    {:noreply, assign(socket, selected_team: GrantableTeams.resolve(socket.assigns, identifier))}
  end

  def handle_event("approve", _params, socket) do
    %{current_user: user, selected_team: team, ctx: ctx} = socket.assigns

    case Auth.rate_limit(:oauth_authorize_user, user) do
      :ok ->
        {:noreply, create_code(socket, user, team, ctx)}

      {:error, {:rate_limit, _}} ->
        {:noreply, put_live_flash(socket, :error, @rate_limited_message)}
    end
  end

  def handle_event("deny", _params, socket) do
    {:noreply, redirect_back(socket, error: "access_denied")}
  end

  defp create_code(socket, user, team, ctx) do
    attrs = %{
      client_id: ctx.client_id,
      client_name: ctx.client_name,
      redirect_uri: ctx.redirect_uri,
      code_challenge: ctx.code_challenge,
      code_challenge_method: ctx.code_challenge_method,
      scopes: ctx.scopes,
      resource: ctx.resource
    }

    case OAuth.create_authorization_code(user, team, attrs) do
      {:ok, code} -> redirect_back(socket, code: code)
      {:error, _} -> redirect_back(socket, error: "server_error")
    end
  end

  defp redirect_back(socket, params) do
    %{ctx: ctx} = socket.assigns

    redirect(socket,
      external: AuthorizationResponse.redirect_url(ctx.redirect_uri, params ++ [state: ctx.state])
    )
  end
end
