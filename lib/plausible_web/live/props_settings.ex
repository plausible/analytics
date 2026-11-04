defmodule PlausibleWeb.Live.PropsSettings do
  @moduledoc """
  LiveView allowing listing, allowing and disallowing custom event properties.
  """

  use PlausibleWeb, :live_view

  alias PlausibleWeb.Live.Components.ComboBox

  # capability:begin
  # id: list_custom_props@ui_session
  # action: list_custom_props
  # transport: ui_session
  # entry: live /:domain/settings/properties (live_render PropsSettings) mount
  # handler: PlausibleWeb.Live.PropsSettings.mount/3
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, guest_editor, super_admin]
  # current_role_enforced_by: PropsSettings.mount -> Sites.get_for_user!(roles: [:owner, :admin, :editor, :super_admin]) (coalesce(guest role, team role)); page: SiteController plug AuthorizeSiteAccess [:owner, :admin, :editor, :super_admin]
  # current_feature_gate: none
  # proposed_scope: sites:read
  # proposed_roles: [owner, admin, editor, viewer, billing, guest_viewer, guest_editor]
  # confidence: verified
  # notes: Settings page is editor and above; the Sites API lets viewers list props
  # capability:end
  def mount(_params, %{"site_id" => site_id, "domain" => domain}, socket) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        Plausible.Sites.get_for_user!(current_user, domain,
          roles: [
            :owner,
            :admin,
            :editor,
            :super_admin
          ],
          include_consolidated?: true
        )
      end)
      |> assign_new(:all_props, fn %{site: site} ->
        site.allowed_event_props || []
      end)
      |> assign_new(:displayed_props, fn %{all_props: props} ->
        props
      end)

    {:ok,
     assign(socket,
       site_team: socket.assigns.site.team,
       site_id: site_id,
       domain: domain,
       add_prop?: false,
       filter_text: ""
     )}
  end

  def render(assigns) do
    ~H"""
    <section id="props-settings-main">
      <.flash_messages flash={@flash} />
      <.tile
        docs="custom-props/introduction"
        feature_mod={Plausible.Billing.Feature.Props}
        feature_toggle?={true}
        show_content?={!Plausible.Billing.Feature.Props.opted_out?(@site)}
        site={@site}
        current_user={@current_user}
        current_team={@site_team}
      >
        <:title>
          Custom properties
        </:title>
        <:subtitle :if={Enum.count(@all_props) > 0}>
          Attach custom properties when sending a pageview or an event to
          create custom metrics.
        </:subtitle>
        <%= if @add_prop? do %>
          {live_render(
            @socket,
            PlausibleWeb.Live.PropsSettings.Form,
            id: "props-form",
            session: %{
              "domain" => @domain,
              "site_id" => @site_id,
              "rendered_by" => self()
            }
          )}
        <% end %>

        <.live_component
          module={PlausibleWeb.Live.PropsSettings.List}
          id="props-list"
          props={@displayed_props}
          domain={@domain}
          filter_text={@filter_text}
        />
      </.tile>
    </section>
    """
  end

  def handle_event("allow", %{"prop" => prop}, socket) do
    case Plausible.Props.allow(socket.assigns.site, prop) do
      {:ok, site} ->
        send_update(ComboBox, id: :prop_input, display_value: "", submit_value: "")

        {:noreply,
         assign(socket,
           site: site,
           form: new_form(site)
         )}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end

  def handle_event("add-prop", _value, socket) do
    {:noreply, assign(socket, add_prop?: true)}
  end

  def handle_event("filter", %{"filter-text" => filter_text}, socket) do
    new_list =
      ComboBox.StaticSearch.suggest(
        filter_text,
        socket.assigns.all_props
      )

    {:noreply, assign(socket, displayed_props: new_list, filter_text: filter_text)}
  end

  def handle_event("reset-filter-text", _params, socket) do
    {:noreply, assign(socket, filter_text: "", displayed_props: socket.assigns.all_props)}
  end

  # capability:begin
  # id: delete_custom_prop@ui_session
  # action: delete_custom_prop
  # transport: ui_session
  # entry: live /:domain/settings/properties (live_render PropsSettings) handle_event "disallow-prop"
  # handler: PlausibleWeb.Live.PropsSettings.handle_event/3
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [owner, admin, editor, guest_editor, super_admin]
  # current_role_enforced_by: PropsSettings.mount -> Sites.get_for_user!(roles: [:owner, :admin, :editor, :super_admin]) (coalesce(guest role, team role))
  # current_feature_gate: none
  # proposed_scope: sites:write
  # proposed_roles: [owner, admin, editor, guest_editor]
  # confidence: verified
  # notes: no Teams.locked? check in the UI, the Sites API checks it; handle_event "allow" and "allow-existing-props" in this module look unused (the Form LiveView handles them)
  # capability:end
  def handle_event("disallow-prop", %{"prop" => prop}, socket) do
    {:ok, site} = Plausible.Props.disallow(socket.assigns.site, prop)

    socket =
      socket
      |> put_live_flash(:success, "Property removed successfully")
      |> assign(
        all_props: Enum.reject(socket.assigns.all_props, &(&1 == prop)),
        displayed_props: Enum.reject(socket.assigns.displayed_props, &(&1 == prop)),
        site: site
      )

    {:noreply, socket}
  end

  def handle_event("allow-existing-props", _params, socket) do
    {:ok, site} = Plausible.Props.allow_existing_props(socket.assigns.site)

    {:noreply,
     assign(socket,
       site: site
     )}
  end

  def handle_info(:cancel_add_prop, socket) do
    {:noreply, assign(socket, add_prop?: false)}
  end

  def handle_info({:feature_toggled, flash_msg, updated_site}, socket) do
    {:noreply, assign(put_flash(socket, :success, flash_msg), site: updated_site)}
  end

  def handle_info({:props_allowed, props}, socket) when is_list(props) do
    socket =
      socket
      |> assign(
        add_prop?: false,
        filter_text: "",
        all_props: props,
        displayed_props: props,
        site: %{socket.assigns.site | allowed_event_props: props}
      )
      |> put_live_flash(:success, "Properties added successfully")

    {:noreply, socket}
  end

  def handle_info(
        {:prop_allowed, prop},
        %{assigns: %{site: site}} = socket
      )
      when is_binary(prop) do
    allowed_event_props = [prop | site.allowed_event_props || []]

    socket =
      socket
      |> assign(
        add_prop?: false,
        filter_text: "",
        all_props: allowed_event_props,
        displayed_props: allowed_event_props,
        site: %{site | allowed_event_props: allowed_event_props}
      )
      |> put_live_flash(:success, "Property added successfully")

    {:noreply, socket}
  end

  defp new_form(site) do
    to_form(Plausible.Props.allow_changeset(site, []))
  end
end
