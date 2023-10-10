defmodule PlausibleWeb.Live.PropsSettings do
  @moduledoc """
  LiveView allowing listing, allowing and disallowing custom event properties.
  """

  use PlausibleWeb, :live_view
  alias PlausibleWeb.Live.Components.ComboBox
  alias PlausibleWeb.Live.PropsSettings.FormComponent

  def mount(
        _params,
        %{"site_id" => site_id, "domain" => domain, "current_user_id" => user_id},
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn ->
        Plausible.Sites.get_for_user!(user_id, domain, [:owner, :admin, :super_admin])
      end)
      |> assign_new(:all_props, fn %{site: site} ->
        site.allowed_event_props || []
      end)
      |> assign_new(:displayed_props, fn %{all_props: props} ->
        props
      end)

    {:ok,
     assign(socket,
       site_id: site_id,
       domain: domain,
       current_user_id: user_id,
       filter_text: ""
     )}
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

  def handle_event("disallow-prop", %{"prop" => prop}, socket) do
    {:ok, site} = Plausible.Props.disallow(socket.assigns.site, prop)

    socket =
      socket
      |> put_flash(:success, "Property removed successfully")
      |> assign(
        all_props: Enum.reject(socket.assigns.all_props, &(&1 == prop)),
        displayed_props: Enum.reject(socket.assigns.displayed_props, &(&1 == prop)),
        site: site
      )

    ComboBox.reset("prop_input")

    Process.send_after(self(), :clear_flash, 5000)
    {:noreply, socket}
  end

  def handle_event("allow-existing-props", _params, socket) do
    {:ok, site} = Plausible.Props.allow_existing_props(socket.assigns.site)

    {:noreply,
     assign(socket,
       site: site
     )}
  end

  def handle_event("modal-closed", _param, socket) do
    ComboBox.reset("prop_input")

    {:noreply, socket}
  end

  def handle_info(
        {FormComponent, {:prop_allowed, prop}},
        %{assigns: %{site: site}} = socket
      )
      when is_binary(prop) do
    allowed_event_props = [prop | site.allowed_event_props || []]

    socket = push_event(socket, "close-modal", %{id: "add-prop"})

    socket =
      socket
      |> assign(
        filter_text: "",
        all_props: allowed_event_props,
        displayed_props: allowed_event_props,
        site: %{site | allowed_event_props: allowed_event_props}
      )
      |> put_flash(:success, "Property added successfully")

    {:noreply, socket}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  defp delete_confirmation_text(prop) do
    """
    Are you sure you want to remove the following property:

    #{prop}

    This will just affect the UI, all of your analytics data will stay intact.
    """
  end
end
