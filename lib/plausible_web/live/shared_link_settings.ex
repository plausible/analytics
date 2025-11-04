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

      <p :if={Enum.empty?(@shared_links)} class="mb-8 text-center text-sm">
        No shared links configured for this site.
      </p>

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
              <.tooltip :if={link.password_hash} enabled?={true} centered?={true}>
                <:tooltip_content>
                  Password protected
                </:tooltip_content>
                <Heroicons.lock_closed class="feather ml-2 mb-0.5" />
              </.tooltip>
              <.tooltip :if={!link.password_hash} enabled?={true} centered?={true}>
                <:tooltip_content>
                  No password protection
                </:tooltip_content>
                <Heroicons.lock_open class="feather ml-2 mb-0.5" />
              </.tooltip>
              <.tooltip enabled?={true} centered?={true}>
                <:tooltip_content>
                  Limited view
                </:tooltip_content>
                <Heroicons.eye_slash class="feather ml-1" />
              </.tooltip>
            </div>
          </.td>
          <.td>
            <.input_with_clipboard
              name={link.slug}
              id={link.slug}
              value={shared_link_dest(@site, link)}
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
    """
  end

  def handle_event("add-shared-link", _, socket) do
    socket = socket |> assign(form_shared_link: nil) |> Modal.open("shared-links-form-modal")
    {:noreply, socket}
  end

  def handle_event("edit-shared-link", %{"slug" => slug}, socket) do
    shared_link = Plausible.Repo.get_by(Plausible.Site.SharedLink, slug: slug)

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

  defp shared_link_dest(site, link) do
    Routes.stats_path(PlausibleWeb.Endpoint, :shared_link, site.domain, auth: link.slug)
  end
end
