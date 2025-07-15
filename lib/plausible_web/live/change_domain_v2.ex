defmodule PlausibleWeb.Live.ChangeDomainV2 do
  @moduledoc """
  LiveView for the change domain v2 flow.
  """
  use PlausibleWeb, :live_view

  alias Plausible.Site
  alias PlausibleWeb.Router.Helpers, as: Routes

  def mount(
        %{"domain" => domain},
        _session,
        socket
      ) do
    site =
      Plausible.Sites.get_for_user!(socket.assigns.current_user, domain, [
        :owner,
        :admin,
        :super_admin
      ])

    changeset = Site.update_changeset(site)

    {:ok,
     assign(socket,
       site: site,
       changeset: changeset,
       domain: domain
     )}
  end

  def render(assigns) do
    ~H"""
    <.focus_box>
      <:title>Change your website domain</:title>
      <:subtitle>
        If you have changed the domain name of your site and would like your new domain name to be displayed in your Plausible dashboard, you can do so here. You won't lose any of your historical stats in this process.
      </:subtitle>

      <:footer>
        <.focus_list>
          <:item>
            Changed your mind? Go back to
            <.styled_link href={Routes.site_path(@socket, :settings_general, @site.domain)}>
              Site Settings
            </.styled_link>
          </:item>
        </.focus_list>
      </:footer>

      <.form :let={f} for={@changeset} phx-submit="submit">
        <.input
          help_text="Just the naked domain or subdomain without 'www', 'https' etc."
          type="text"
          placeholder="example.com"
          field={f[:domain]}
          label="Domain"
        />

      <.button type="submit" class="mt-4 w-full">
          Change Domain
        </.button>

        <.notice class="mt-4" title="Additional Steps May Be Required">
        If you are using the Wordpress plugin, NPM module, or Events API for tracking, you must also update the tracking
        <code>domain</code>
        to match the updated domain. See
        <.styled_link new_tab href="https://plausible.io/docs/change-domain-name/">
          documentation
        </.styled_link>
        for details.
        </.notice>

      </.form>

    </.focus_box>
    """
  end

  def handle_event("submit", %{"site" => %{"domain" => new_domain}}, socket) do
    case Site.Domain.change(socket.assigns.site, new_domain) do
      {:ok, updated_site} ->
        {:noreply,
         socket
         |> put_flash(:success, "Website domain changed successfully")
         |> push_navigate(to: Routes.site_path(socket, :settings_general, updated_site.domain))}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
