defmodule PlausibleWeb.Live.Plugins.API.Settings do
  @moduledoc """
  LiveView allowing listing, creating and revoking Plugins API tokens.
  """

  use PlausibleWeb, :live_view

  alias Plausible.Plugins.API.Tokens

  # capability:begin
  # id: list_plugins_tokens@ui_session
  # action: list_plugins_tokens
  # transport: ui_session
  # entry: live /:domain/settings/integrations (live_render Plugins.API.Settings) mount
  # handler: PlausibleWeb.Live.Plugins.API.Settings.mount/3
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, guest_editor, super_admin]
  # current_role_enforced_by: Plugins.API.Settings.mount -> Sites.get_for_user!(roles: [:owner, :admin, :editor, :super_admin]) (coalesce(guest role, team role))
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: Token descriptions and last use; credential management stays session only
  # capability:end
  def mount(_params, %{"domain" => domain} = session, socket) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        Plausible.Sites.get_for_user!(current_user, domain,
          roles: [
            :owner,
            :admin,
            :editor,
            :super_admin
          ]
        )
      end)
      |> assign_new(:displayed_tokens, fn %{site: site} ->
        Tokens.list(site)
      end)

    {:ok,
     assign(socket,
       domain: domain,
       create_token?: not is_nil(session["new_token"]),
       token_description: session["new_token"] || ""
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.flash_messages flash={@flash} />

      <%= if @create_token? do %>
        {live_render(
          @socket,
          PlausibleWeb.Live.Plugins.API.TokenForm,
          id: "token-form",
          session: %{
            "domain" => @domain,
            "token_description" => @token_description,
            "rendered_by" => self()
          }
        )}
      <% end %>

      <%= if Enum.empty?(@displayed_tokens) do %>
        <div class="flex flex-col items-center justify-center pt-5 pb-6 max-w-md mx-auto">
          <h3 class="text-center text-base font-medium text-gray-900 dark:text-gray-100 leading-7">
            Create your first plugin token
          </h3>
          <p class="text-center text-sm mt-1 text-gray-500 dark:text-gray-400 leading-5 text-pretty">
            Control plugin access by creating tokens for third-party integrations.
          </p>
          <.button
            phx-click="create-token"
            class="mt-6"
          >
            New plugin token
          </.button>
        </div>
      <% else %>
        <.filter_bar filtering_enabled?={false}>
          <.button phx-click="create-token">
            Create plugin token
          </.button>
        </.filter_bar>

        <.table rows={@displayed_tokens}>
          <:thead>
            <.th>Description</.th>
            <.th hide_on_mobile>Hint</.th>
            <.th hide_on_mobile>Last used</.th>
            <.th invisible>Actions</.th>
          </:thead>
          <:tbody :let={token}>
            <.td>
              <span class="token-description">
                {token.description}
              </span>
            </.td>
            <.td hide_on_mobile>
              **********{token.hint}
            </.td>
            <.td hide_on_mobile>
              {PlausibleWeb.TextHelpers.humanize_last_used(token.last_used_at)}
            </.td>
            <.td actions>
              <.delete_button
                id={"revoke-token-#{token.id}"}
                phx-click="revoke-token"
                phx-value-token-id={token.id}
                data-confirm="Are you sure you want to revoke this Token? This action cannot be reversed."
              />
            </.td>
          </:tbody>
        </.table>
      <% end %>
    </div>
    """
  end

  def handle_event("create-token", _params, socket) do
    {:noreply, assign(socket, :create_token?, true)}
  end

  # capability:begin
  # id: revoke_plugins_token@ui_session
  # action: revoke_plugins_token
  # transport: ui_session
  # entry: live /:domain/settings/integrations (live_render Plugins.API.Settings) handle_event "revoke-token"
  # handler: PlausibleWeb.Live.Plugins.API.Settings.handle_event/3
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, guest_editor, super_admin]
  # current_role_enforced_by: Plugins.API.Settings.mount -> Sites.get_for_user!(roles: [:owner, :admin, :editor, :super_admin]) (coalesce(guest role, team role))
  # current_feature_gate: none
  # proposed_scope: none
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # capability:end
  def handle_event("revoke-token", %{"token-id" => token_id}, socket) do
    :ok = Tokens.delete(socket.assigns.site, token_id)
    displayed_tokens = Enum.reject(socket.assigns.displayed_tokens, &(&1.id == token_id))
    {:noreply, assign(socket, create_token?: false, displayed_tokens: displayed_tokens)}
  end

  def handle_info(:close_token_modal, socket) do
    {:noreply, assign(socket, create_token?: false)}
  end

  def handle_info({:token_created, token}, socket) do
    displayed_tokens = [token | socket.assigns.displayed_tokens]

    socket = put_live_flash(socket, :success, "Plugins Token created successfully")

    {:noreply,
     assign(socket,
       displayed_tokens: displayed_tokens,
       token_description: ""
     )}
  end
end
