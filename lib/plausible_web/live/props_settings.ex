defmodule PlausibleWeb.Live.PropsSettings do
  @moduledoc """
  LiveView allowing listing, allowing and disallowing custom event properties.
  """

  use Phoenix.LiveView
  use Phoenix.HTML
  alias PlausibleWeb.Live.Components.ComboBox.StaticSearch

  def mount(
        _params,
        %{"site_id" => _site_id, "domain" => domain, "current_user_id" => user_id},
        socket
      ) do
    true = Plausible.Props.enabled_for?(%Plausible.Auth.User{id: user_id})

    site =
      if Plausible.Auth.is_super_admin?(user_id) do
        Plausible.Sites.get_by_domain(domain)
      else
        Plausible.Sites.get_for_user!(user_id, domain, [:owner, :admin])
      end

    {:ok,
     assign(socket,
       site: site,
       domain: domain,
       current_user_id: user_id,
       add_prop?: false,
       list: site.allowed_event_props || [],
       props: site.allowed_event_props || [],
       filter_text: ""
     )}
  end

  def render(assigns) do
    ~H"""
    <section id="props-settings-main">
      <.live_component id="embedded_liveview_flash" module={PlausibleWeb.Live.Flash} flash={@flash} />
      <%= if @add_prop? do %>
        <%= live_render(
          @socket,
          PlausibleWeb.Live.PropsSettings.Form,
          id: "props-form",
          session: %{
            "current_user_id" => @current_user_id,
            "domain" => @domain,
            "site_id" => @site.id,
            "rendered_by" => self()
          }
        ) %>
      <% end %>

      <.live_component
        module={PlausibleWeb.Live.PropsSettings.List}
        id="props-list"
        props={@list}
        domain={@domain}
        filter_text={@filter_text}
      />
    </section>
    """
  end

  def handle_event("add-prop", _value, socket) do
    {:noreply, assign(socket, add_prop?: true)}
  end

  def handle_event("filter", %{"filter-text" => filter_text}, socket) do
    new_list =
      StaticSearch.suggest(
        filter_text,
        socket.assigns.props
      )

    {:noreply, assign(socket, list: new_list, filter_text: filter_text)}
  end

  def handle_event("reset-filter-text", _params, socket) do
    {:noreply, assign(socket, filter_text: "", list: socket.assigns.props)}
  end

  def handle_event("disallow", %{"prop" => prop}, socket) do
    {:ok, site} = Plausible.Props.disallow(socket.assigns.site, prop)

    socket =
      socket
      |> put_flash(:success, "Property removed successfully")
      |> assign(
        props: Enum.reject(socket.assigns.props, &(&1 == prop)),
        list: Enum.reject(socket.assigns.list, &(&1 == prop)),
        site: site
      )

    Process.send_after(self(), :clear_flash, 5000)
    {:noreply, socket}
  end

  def handle_info(:cancel_add_prop, socket) do
    {:noreply, assign(socket, add_prop?: false)}
  end

  def handle_info({:props_added, props}, socket) when is_list(props) do
    socket =
      socket
      |> assign(
        add_prop?: false,
        filter_text: "",
        props: props,
        list: props
      )
      |> put_flash(:success, "Properties added successfully")

    {:noreply, socket}
  end

  def handle_info({:prop_added, prop}, socket) do
    socket =
      socket
      |> assign(
        add_prop?: false,
        filter_text: "",
        props: [prop | socket.assigns.props],
        list: [prop | socket.assigns.props]
      )
      |> put_flash(:success, "Property added successfully")

    {:noreply, socket}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end
end
