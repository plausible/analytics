defmodule PlausibleWeb.Live.SharedLinkSettings.Form do
  @moduledoc """
  Live view for the shared link creation form
  """
  use PlausibleWeb, :live_component
  use Plausible

  alias Plausible.Sites
  alias PlausibleWeb.Live.Components.ComboBox

  def update(assigns, socket) do
    form =
      (assigns.shared_link || %Plausible.Site.SharedLink{})
      |> Plausible.Site.SharedLink.changeset(%{})
      |> to_form()

    socket =
      socket
      |> assign(
        id: assigns.id,
        context_unique_id: assigns.context_unique_id,
        form: form,
        site: assigns.site,
        shared_link: assigns.shared_link,
        on_save_shared_link: assigns.on_save_shared_link
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div id={@id}>
      {if @shared_link, do: edit_form(assigns)}
      {if is_nil(@shared_link), do: create_form(assigns)}
    </div>
    """
  end

  def edit_form(assigns) do
    ~H"""
    <.form :let={f} for={@form} phx-submit="save-shared-link" phx-target={@myself}>
      <.title>Edit shared link</.title>

      <.input field={f[:name]} label="Name" required="required" autocomplete="off" />

      <div
        x-data={"{ limitViewEnabled: #{not is_nil(f[:segment_id].value)} }"}
        x-effect="
          const input = document.getElementById('submit-segment_id');
          if (input) {
            if (!limitViewEnabled) {
              input.value = '';
            }
          }
        "
        class="flex flex-col gap-y-2"
      >
        <PlausibleWeb.Components.Generic.toggle_field
          id="limit-view"
          id_suffix=""
          js_active_var="limitViewEnabled"
          label="Limit to segment"
          help_text="Restrict this link to a segment of the data."
        />
        <div x-show="limitViewEnabled" x-cloak>
          <.live_component
            id="segment_id"
            submit_name="shared_link[segment_id]"
            module={ComboBox}
            suggest_fun={
              fn input, _ ->
                {:ok, segments} = Plausible.Segments.search_by_name(assigns.site, input, type: :site)
                Enum.map(segments, &{&1.id, &1.name})
              end
            }
            selected={
              @shared_link.segment_id &&
                {@shared_link.limited_to_segment.id, @shared_link.limited_to_segment.name}
            }
          />
        </div>
      </div>

      <.button type="submit" class="w-full">
        Update shared link
      </.button>
    </.form>
    """
  end

  def create_form(assigns) do
    ~H"""
    <.form :let={f} for={@form} phx-submit="save-shared-link" phx-target={@myself}>
      <.title>New shared link</.title>
      <.input field={f[:name]} label="Name" required="required" autocomplete="off" />

      <div
        x-data="{ passwordProtectEnabled: false }"
        x-effect={"
          const input = document.getElementById('#{f[:password].id}');
          if (input) {
            if (passwordProtectEnabled) {
              setTimeout(() => input.focus(), 50);
            } else {
              input.value = '';
            }
          }
        "}
        class="flex flex-col gap-y-2"
      >
        <PlausibleWeb.Components.Generic.toggle_field
          id="password-protect"
          id_suffix=""
          js_active_var="passwordProtectEnabled"
          label="Password protect"
          help_text="Keep this password safe. You won't be able to see it again."
          help_text_conditional={true}
        />
        <div x-show="passwordProtectEnabled" x-cloak>
          <.input
            field={f[:password]}
            type="password"
            placeholder="Enter password"
            autocomplete="new-password"
            mt?={false}
          />
        </div>
      </div>

      <div
        x-data={"{ limitViewEnabled: #{not is_nil(f[:segment_id].value)} }"}
        x-effect="
          const input = document.getElementById('submit-segment_id');
          if (input) {
            if (!limitViewEnabled) {
              input.value = '';
            }
          }
        "
        class="flex flex-col gap-y-2"
      >
        <PlausibleWeb.Components.Generic.toggle_field
          id="limit-view"
          id_suffix=""
          js_active_var="limitViewEnabled"
          label="Limit to segment"
          help_text="Restrict this link to a segment of the data."
        />
        <div x-show="limitViewEnabled" x-cloak>
          <.live_component
            id="segment_id"
            submit_name="shared_link[segment_id]"
            module={ComboBox}
            suggest_fun={
              fn input, _ ->
                {:ok, segments} = Plausible.Segments.search_by_name(assigns.site, input, type: :site)
                Enum.map(segments, &{&1.id, &1.name})
              end
            }
            selected={nil}
          />
        </div>
      </div>
      <.button type="submit" class="w-full">
        Create shared link
      </.button>
    </.form>
    """
  end

  def handle_event(
        "save-shared-link",
        %{"shared_link" => shared_link_params},
        %{assigns: %{shared_link: nil}} = socket
      ) do
    case Sites.create_shared_link(socket.assigns.site, shared_link_params["name"],
           password: shared_link_params["password"],
           segment_id: shared_link_params["segment_id"]
         ) do
      {:ok, shared_link} ->
        socket = socket.assigns.on_save_shared_link.(shared_link, socket)
        {:noreply, socket}

      {:error, :upgrade_required} ->
        socket =
          socket
          |> put_flash(:error, "Your current subscription plan does not include Shared Links")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event(
        "save-shared-link",
        %{"shared_link" => shared_link_params},
        %{assigns: %{shared_link: %Plausible.Site.SharedLink{} = shared_link}} = socket
      ) do
    changeset =
      Plausible.Site.SharedLink.changeset(
        shared_link,
        shared_link_params
      )

    case Plausible.Repo.update(changeset) do
      {:ok, updated_shared_link} ->
        socket = socket.assigns.on_save_shared_link.(updated_shared_link, socket)
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
