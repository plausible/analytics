defmodule PlausibleWeb.Live.SharedLinkSettings do
  @moduledoc """
  LiveView allowing listing, creating and deleting shared links.
  """
  use PlausibleWeb, :live_view

  alias PlausibleWeb.Live.Components.Modal
  import Ecto.Query

  def mount(
        _params,
        %{"site_id" => site_id, "domain" => domain},
        socket
      ) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        current_user
        |> Plausible.Sites.get_for_user!(domain, roles: [:owner, :admin, :editor, :super_admin])
      end)
      |> assign_new(:shared_links, fn %{site: site} ->
        Plausible.Repo.all(
          from(l in Plausible.Site.SharedLink,
            where:
              l.site_id == ^site.id and l.name not in ^Plausible.Sites.shared_link_special_names(),
            order_by: [desc: l.id]
          )
        )
      end)

    {:ok,
     assign(socket,
       site_id: site_id,
       domain: domain,
       form_shared_link: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div id="shared-link-settings-main">
      <.flash_messages flash={@flash} />

      <.tile
        docs="shared-links"
        feature_mod={Plausible.Billing.Feature.SharedLinks}
        site={@site}
        current_user={@current_user}
        current_team={@current_team}
      >
        <:title>
          Shared links
        </:title>
        <:subtitle :if={Enum.count(@shared_links) > 0}>
          Share your stats privately with anyone. Links are unique, secure, and can be password-protected.
        </:subtitle>

        <.live_component
          :let={modal_unique_id}
          module={Modal}
          preload?={false}
          id="shared-links-form-modal"
        >
          <.live_component
            module={PlausibleWeb.Live.SharedLinkSettings.Form}
            id={"shared-links-form-#{modal_unique_id}"}
            context_unique_id={modal_unique_id}
            site={@site}
            shared_link={@form_shared_link}
            on_save_shared_link={
              fn shared_link, socket ->
                send(self(), {:shared_link_added, shared_link})
                Modal.close(socket, "shared-links-form-modal")
              end
            }
          />
        </.live_component>

        <%= if Enum.empty?(@shared_links) do %>
          <div class="flex flex-col items-center justify-center pt-5 pb-6 max-w-md mx-auto">
            <h3 class="text-center text-base font-medium text-gray-900 dark:text-gray-100 leading-7">
              Create your first shared link
            </h3>
            <p class="text-center text-sm mt-1 text-gray-500 dark:text-gray-400 leading-5 text-pretty">
              Share your stats privately with anyone. Links are unique, secure, and can be password-protected.
              <.styled_link href="https://plausible.io/docs/shared-links" target="_blank">
                Learn more
              </.styled_link>
            </p>
            <.button
              id="add-shared-link-button"
              phx-click="add-shared-link"
              x-data
              x-on:click={Modal.JS.preopen("shared-links-form-modal")}
              class="mt-4"
            >
              Add shared link
            </.button>
          </div>
        <% else %>
          <div class="flex flex-col gap-4">
            <.filter_bar filtering_enabled?={false}>
              <.button
                id="add-shared-link-button"
                phx-click="add-shared-link"
                mt?={false}
                x-data
                x-on:click={Modal.JS.preopen("shared-links-form-modal")}
              >
                Add shared link
              </.button>
            </.filter_bar>

            <.table rows={@shared_links} id="shared-links-table">
              <:thead>
                <.th hide_on_mobile>Name</.th>
                <.th>Link</.th>
                <.th invisible>Actions</.th>
              </:thead>
              <:tbody :let={link}>
                <.td truncate hide_on_mobile>
                  <div class="flex items-center">
                    {link.name}
                    <.tooltip
                      :if={Plausible.Site.SharedLink.password_protected?(link)}
                      enabled?={true}
                      centered?={true}
                    >
                      <:tooltip_content>
                        Password protected
                      </:tooltip_content>
                      <Heroicons.lock_closed class="size-3.5 mt-px ml-2 mb-0.5 stroke-2" />
                    </.tooltip>
                    <.tooltip
                      :if={!Plausible.Site.SharedLink.password_protected?(link)}
                      enabled?={true}
                      centered?={true}
                    >
                      <:tooltip_content>
                        No password protection
                      </:tooltip_content>
                      <Heroicons.lock_open class="size-3.5 mt-px ml-2 mb-0.5 stroke-2" />
                    </.tooltip>
                    <.tooltip :if={link.segment_id} enabled?={true} centered?={true}>
                      <:tooltip_content>
                        Limited to segment of data
                      </:tooltip_content>
                      <Heroicons.eye_slash class="size-3.5 mt-px ml-1 stroke-2" />
                    </.tooltip>
                  </div>
                </.td>
                <.td>
                  <.input_with_clipboard
                    name={link.slug}
                    id={link.slug}
                    value={Plausible.Sites.shared_link_url(@site, link)}
                  />
                </.td>
                <.td actions>
                  <.edit_button
                    class="mt-1"
                    phx-click="edit-shared-link"
                    phx-value-slug={link.slug}
                  />
                  <.delete_button
                    class="mt-1"
                    phx-click="delete-shared-link"
                    phx-value-slug={link.slug}
                    data-confirm="Are you sure you want to delete this shared link? The stats will not be accessible with this link anymore."
                  />
                </.td>
              </:tbody>
            </.table>
          </div>
        <% end %>
      </.tile>
    </div>
    """
  end

  def handle_event("add-shared-link", _, socket) do
    socket = socket |> assign(form_shared_link: nil) |> Modal.open("shared-links-form-modal")
    {:noreply, socket}
  end

  def handle_event("edit-shared-link", %{"slug" => slug}, socket) do
    shared_link =
      Plausible.Site.SharedLink
      |> Plausible.Repo.get_by(slug: slug)
      |> Plausible.Repo.preload(:segment)

    socket =
      socket |> assign(form_shared_link: shared_link) |> Modal.open("shared-links-form-modal")

    {:noreply, socket}
  end

  def handle_event("delete-shared-link", %{"slug" => slug}, socket) do
    site_id = socket.assigns.site.id

    case Plausible.Repo.delete_all(
           from(l in Plausible.Site.SharedLink,
             where: l.slug == ^slug,
             where: l.site_id == ^site_id
           )
         ) do
      {1, _} ->
        socket =
          socket
          |> put_live_flash(:success, "Shared link deleted")
          |> assign(shared_links: Enum.reject(socket.assigns.shared_links, &(&1.slug == slug)))

        {:noreply, socket}

      {0, _} ->
        socket =
          socket
          |> put_live_flash(:error, "Could not find Shared Link")

        {:noreply, socket}
    end
  end

  def handle_info({:shared_link_added, _shared_link}, socket) do
    shared_links =
      Plausible.Repo.all(
        from(l in Plausible.Site.SharedLink,
          where:
            l.site_id == ^socket.assigns.site.id and
              l.name not in ^Plausible.Sites.shared_link_special_names(),
          order_by: [desc: l.id]
        )
      )

    socket =
      socket
      |> assign(
        shared_links: shared_links,
        form_shared_link: nil
      )
      |> put_live_flash(:success, "Shared link saved")

    {:noreply, socket}
  end
end
