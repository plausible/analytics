defmodule PlausibleWeb.CustomerSupport.Live.Site do
  use Plausible.CustomerSupport.Resource, :component

  def update(assigns, socket) do
    site = Resource.Site.get(assigns.resource_id)

    changeset = Plausible.Site.crm_changeset(site, %{})
    form = to_form(changeset)

    {:ok, assign(socket, site: site, form: form, tab: "overview")}
  end

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="flex items-center">
        <div class="rounded-full p-1 mr-4">
          <.favicon class="w-8" domain={@site.domain} />
        </div>

        <div>
          <p class="text-xl font-bold sm:text-2xl">
            {@site.domain}
          </p>
          <p class="text-sm font-medium">
            Timezone: {@site.timezone}
          </p>
          <p class="text-sm font-medium">
            Team:
            <.styled_link phx-click="open" phx-value-id={@site.team.id} phx-value-type="team">
              {@site.team.name}
            </.styled_link>
          </p>
          <p class="text-sm font-medium">
            <span :if={@site.domain_changed_from}>(previously: {@site.domain_changed_from})</span>
          </p>
        </div>
      </div>

      <div>
        <div class="grid grid-cols-1 sm:hidden">
          <!-- Use an "onChange" listener to redirect the user to the selected tab URL. -->
          <select
            aria-label="Select a tab"
            class="col-start-1 row-start-1 w-full appearance-none rounded-md bg-white py-2 pl-3 pr-8 text-base text-gray-900 outline outline-1 -outline-offset-1 outline-gray-300 focus:outline focus:outline-2 focus:-outline-offset-2 focus:outline-indigo-600"
          >
            <option>Overview</option>
            <option>People</option>
          </select>
        </div>
        <div class="hidden sm:block">
          <nav
            class="isolate flex divide-x dark:divide-gray-900 divide-gray-200 rounded-lg shadow dark:shadow-1"
            aria-label="Tabs"
          >
            <.tab to="overview" target={@myself} tab={@tab}>Overview</.tab>
            <.tab to="people" target={@myself} tab={@tab}>
              People
            </.tab>
          </nav>
        </div>
      </div>

      <.form
        :let={f}
        :if={@tab == "overview"}
        for={@form}
        phx-target={@myself}
        phx-submit="change"
        class="mt-8"
      >
        <.input
          type="select"
          field={f[:timezone]}
          label="Timezone"
          options={Plausible.Timezones.options()}
        />
        <.input type="checkbox" field={f[:public]} label="Public?" />
        <.input type="datetime-local" field={f[:native_stats_start_at]} label="Native Stats Start At" />
        <.input
          type="text"
          field={f[:ingest_rate_limit_threshold]}
          label="Ingest Rate Limit Threshold"
        />
        <.input
          type="text"
          field={f[:ingest_rate_limit_scale_seconds]}
          label="Ingest Rate Limit Scale Seconds"
        />
        <.button phx-target={@myself} type="submit">
          Save
        </.button>
      </.form>

      <div :if={@tab == "people"} class="mt-8">
        <.table rows={@people}>
          <:thead>
            <.th>User</.th>
            <.th>Kind</.th>
            <.th>Role</.th>
          </:thead>
          <:tbody :let={{kind, person, role}}>
            <.td :if={kind == :membership}>
              <.styled_link
                class="flex items-center"
                phx-click="open"
                phx-value-id={person.id}
                phx-value-type="user"
              >
                <img
                  src={Plausible.Auth.User.profile_img_url(person)}
                  class="w-4 rounded-full bg-gray-300 mr-2"
                />
                {person.name}
              </.styled_link>
            </.td>

            <.td :if={kind == :invitation}>
              <div class="flex items-center">
                <img
                  src={Plausible.Auth.User.profile_img_url(person)}
                  class="w-4 rounded-full bg-gray-300 mr-2"
                />
                {person}
              </div>
            </.td>

            <.td :if={kind == :membership}>
              Membership
            </.td>

            <.td :if={kind == :invitation}>
              Invitation
            </.td>
            <.td>{role}</.td>
          </:tbody>
        </.table>
      </div>
    </div>
    """
  end

  def render_result(assigns) do
    ~H"""
    <div class="flex-1 -mt-px w-full">
      <div class="w-full flex items-center justify-between space-x-4">
        <.favicon class="w-5" domain={@resource.object.domain} />
        <h3
          class="text-gray-900 font-medium text-lg truncate dark:text-gray-100"
          style="width: calc(100% - 4rem)"
        >
          {@resource.object.domain}
        </h3>

        <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
          Site
        </span>
      </div>

      <hr class="mt-4 mb-4 flex-grow border-t border-gray-200 dark:border-gray-600" />
      <div class="text-sm">
        Part of <strong>{@resource.object.team.name}</strong>
        owned by {@resource.object.team.owners
        |> Enum.map(& &1.name)
        |> Enum.join(", ")}
      </div>
    </div>
    """
  end

  attr :domain, :string, required: true
  attr :class, :string, required: true

  def favicon(assigns) do
    ~H"""
    <img src={"/favicon/sources/#{@domain}"} class={@class} />
    """
  end

  def handle_event("switch", %{"to" => "overview"}, socket) do
    {:noreply, assign(socket, tab: "overview")}
  end

  def handle_event("switch", %{"to" => "people"}, socket) do
    people = Plausible.Sites.list_people(socket.assigns.site)

    people =
      (people.invitations ++ people.memberships)
      |> Enum.map(fn p ->
        if Map.has_key?(p, :invitation_id) do
          {:invitation, p.email, p.role}
        else
          {:membership, p.user, p.role}
        end
      end)

    {:noreply, assign(socket, tab: "people", people: people)}
  end

  def handle_event("change", %{"site" => params}, socket) do
    changeset = Plausible.Site.crm_changeset(socket.assigns.site, params)

    case Plausible.Repo.update(changeset) do
      {:ok, site} ->
        success(socket, "Site saved")
        {:noreply, assign(socket, site: site, form: to_form(changeset))}

      {:error, changeset} ->
        failure(socket, "Error saving site: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
