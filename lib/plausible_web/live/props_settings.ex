defmodule PlausibleWeb.Live.PropsSettings do
  @moduledoc """
  LiveView allowing listing, allowing and disallowing custom event properties.
  """

  use Phoenix.LiveView
  use Phoenix.HTML
  alias PlausibleWeb.Live.Components.ComboBox

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
       form: new_form(site),
       add_prop?: false,
       list: site.allowed_event_props,
       props: site.allowed_event_props,
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
      PlausibleWeb.Live.Components.ComboBox.StaticSearch.suggest(
        filter_text,
        socket.assigns.props
      )

    {:noreply, assign(socket, list: new_list, filter_text: filter_text)}
  end

  def handle_event("reset-filter-text", _params, socket) do
    {:noreply, assign(socket, filter_text: "", list: socket.assigns.props)}
  end

  def handle_event("allow", %{"prop" => prop}, socket) do
    case Plausible.Props.allow(socket.assigns.site, prop) do
      {:ok, site} ->
        send_update(ComboBox, id: :prop_input, display_value: "", submit_value: "")

        {:noreply,
         assign(socket,
           site: site,
           form: new_form(site),
           suggestions: rebuild_suggestions(socket.assigns.suggestions, site.allowed_event_props)
         )}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(Map.put(changeset, :action, :validate))
         )}
    end
  end

  def handle_event("disallow", %{"prop" => prop}, socket) do
    {:ok, site} = Plausible.Props.disallow(socket.assigns.site, prop)
    {:noreply, assign(socket, site: site)}
  end

  def handle_event("allow-existing-props", _params, socket) do
    {:ok, site} = Plausible.Props.allow_existing_props(socket.assigns.site)

    {:noreply,
     assign(socket,
       site: site,
       suggestions: rebuild_suggestions(socket.assigns.suggestions, site.allowed_event_props)
     )}
  end

  def handle_info(:cancel_add_prop, socket) do
    {:noreply, assign(socket, add_prop?: false)}
  end

  defp rebuild_suggestions(suggestions, allowed_event_props) do
    allowed_event_props = allowed_event_props || []

    suggestions =
      for {suggestion, _} <- suggestions,
          suggestion not in allowed_event_props,
          do: {suggestion, suggestion}

    send_update(ComboBox, id: :prop_input, suggestions: suggestions)
    suggestions
  end

  defp new_form(site) do
    to_form(Plausible.Props.allow_changeset(site, []))
  end
end
