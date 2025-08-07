defmodule PlausibleWeb.Live.ChangeDomainV2.Form do
  @moduledoc """
  Live component for the change domain form
  """
  use PlausibleWeb, :live_component

  def render(assigns) do
    ~H"""
    <div>
      <.form :let={f} for={@changeset} phx-submit="submit" phx-target={@myself}>
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
    </div>
    """
  end

  def handle_event("submit", %{"site" => %{"domain" => new_domain}}, socket) do
    case Plausible.Site.Domain.change(socket.assigns.site, new_domain) do
      {:ok, updated_site} ->
        send(self(), {:domain_changed, updated_site})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
