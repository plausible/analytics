defmodule PlausibleWeb.Live.ChangeDomainV2 do
  @moduledoc """
  LiveView for the change domain v2 flow.
  """
  use PlausibleWeb, :live_view

  alias Plausible.Site
  alias PlausibleWeb.Router.Helpers, as: Routes
  alias PlausibleWeb.Live.ChangeDomainV2.Form

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
       updated_site: nil
     )}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def render(%{live_action: :change_domain_v2} = assigns) do
    render_form_step(assigns)
  end

  def render(%{live_action: :success} = assigns) do
    render_success_step(assigns)
  end

  defp render_form_step(assigns) do
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

      <.live_component module={Form} id="change-domain-form" site={@site} changeset={@changeset} />
    </.focus_box>
    """
  end

  defp render_success_step(assigns) do
    ~H"""
    <.focus_box>
      <:title>Domain Changed Successfully</:title>
      <:subtitle>
        Your website domain has been successfully updated.
      </:subtitle>

      <:footer>
        <.focus_list>
          <:item>
            <.styled_link href={
              Routes.site_path(@socket, :settings_general, (@updated_site || @site).domain)
            }>
              Go to Site Settings
            </.styled_link>
          </:item>
        </.focus_list>
      </:footer>

      <div class="text-center py-8">
        <div class="text-green-600 text-6xl mb-4">✓</div>
        <h2 class="text-2xl font-semibold text-gray-900 mb-2">Success!</h2>
        <%= if @updated_site do %>
          <p class="text-gray-600 mb-6">
            Your website domain has been updated from
            <strong>{@updated_site.domain_changed_from || "previous domain"}</strong>
            to <strong><%= @updated_site.domain %></strong>.
          </p>
        <% else %>
          <p class="text-gray-600 mb-6">
            Your website domain has been successfully changed.
          </p>
        <% end %>
        <.notice class="mb-6" title="Don't Forget!">
          If you are using the Wordpress plugin, NPM module, or Events API for tracking, you must also update the tracking
          <code>domain</code>
          to match the updated domain. See
          <.styled_link new_tab href="https://plausible.io/docs/change-domain-name/">
            documentation
          </.styled_link>
          for details.
        </.notice>
      </div>
    </.focus_box>
    """
  end

  def handle_info({:domain_changed, updated_site}, socket) do
    {:noreply,
     socket
     |> assign(updated_site: updated_site)
     |> push_patch(to: Routes.site_path(socket, :success, updated_site.domain))}
  end
end
