defmodule PlausibleWeb.Live.CustomerSupport.EmailSuppressions do
  @moduledoc """
  Customer Support page for reviewing e-mail suppressions (Postmark bounces
  and spam complaints) and manually reactivating false positives. See
  `Plausible.EmailSuppressions` for how suppressions are recorded and
  enforced.
  """
  use PlausibleWeb.CustomerSupport.Live

  alias Plausible.EmailSuppressions

  @reasons Ecto.Enum.values(Plausible.EmailSuppression, :reason)

  def mount(params, session, socket) do
    {:ok, socket} = super(params, session, socket)
    {:ok, assign(socket, :reasons, @reasons)}
  end

  def handle_params(params, _uri, socket) do
    reason = if params["reason"] in reason_strings(), do: params["reason"]
    pagination_params = Map.take(params, ["after", "before"])

    socket =
      socket
      |> assign(reason: reason, search: params["search"], pagination_params: pagination_params)
      |> assign(:page, list_suppressions(reason, params["search"], pagination_params))

    {:noreply, socket}
  end

  def handle_event("filter", params, socket) do
    query = [reason: params["reason"], search: params["search"]]

    {:noreply, push_patch(socket, to: ~p"/cs/email-suppressions?#{query}")}
  end

  def handle_event("reactivate", %{"email" => email}, socket) do
    socket =
      case EmailSuppressions.reactivate(email, socket.assigns.current_user) do
        {:ok, _suppression} ->
          socket
          |> put_live_flash(:success, "#{email} is no longer suppressed.")
          |> assign(
            :page,
            list_suppressions(
              socket.assigns.reason,
              socket.assigns.search,
              socket.assigns.pagination_params
            )
          )

        {:error, reason} ->
          put_live_flash(socket, :error, reactivate_error_message(email, reason))
      end

    {:noreply, socket}
  end

  defp reactivate_error_message(email, :cannot_activate_in_postmark) do
    "Postmark won't allow #{email} to be reactivated automatically."
  end

  defp reactivate_error_message(email, reason) do
    "Could not reactivate #{email}: (#{inspect(reason)})."
  end

  defp list_suppressions(reason, search, pagination_params) do
    EmailSuppressions.list(
      [reason: reason && String.to_existing_atom(reason), search: search],
      pagination_params
    )
  end

  def render(assigns) do
    ~H"""
    <Layout.layout show_search={false} flash={@flash}>
      <h2 class="text-xl font-bold sm:text-2xl">✉️ E-mail suppressions</h2>

      <form phx-change="filter" class="mt-4 flex flex-wrap items-center gap-3">
        <select
          name="reason"
          class="rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-800 text-sm"
        >
          <option value="">All reasons</option>
          <option
            :for={reason <- @reasons}
            value={reason}
            selected={Atom.to_string(reason) == @reason}
          >
            {reason_label(reason)}
          </option>
        </select>

        <input
          type="text"
          name="search"
          value={@search}
          placeholder="Search by e-mail…"
          class="rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-800 text-sm"
        />
      </form>

      <div class="mt-4">
        <.table rows={@page.entries}>
          <:thead>
            <.th>E-mail</.th>
            <.th>Reason</.th>
            <.th>Source</.th>
            <.th>Status</.th>
            <.th>Suppressed</.th>
            <.th>Action</.th>
          </:thead>
          <:tbody :let={s}>
            <.td>{s.email}</.td>
            <.td>
              <.pill color={reason_color(s.reason)}>{reason_label(s.reason)}</.pill>
            </.td>
            <.td class="capitalize">{s.source}</.td>
            <.td>
              <div :if={is_nil(s.reactivated_at)}>
                <.pill color={:red}>Suppressed</.pill>
              </div>
              <div :if={s.reactivated_at}>
                <.pill color={:green}>Reactivated</.pill>
                <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                  by {reactivated_by_label(s)} on {format_datetime(s.reactivated_at)}
                </div>
              </div>
            </.td>
            <.td>{format_datetime(s.inserted_at)}</.td>
            <.td>
              <div class="flex flex-col items-start gap-1">
                <.styled_link
                  :if={is_nil(s.reactivated_at)}
                  phx-click="reactivate"
                  phx-value-email={s.email}
                  data-confirm={"Reactivate #{s.email}? Plausible will start sending mail to this address again."}
                >
                  Reactivate
                </.styled_link>

                <.dropdown :if={has_postmark_details?(s)} id={"suppression-details-#{s.id}"}>
                  <:button class="!py-0 text-sm text-indigo-600 dark:text-indigo-500 hover:text-indigo-700 dark:hover:text-indigo-400">
                    Details
                  </:button>
                  <:menu class="w-80 p-3 text-xs text-gray-500 dark:text-gray-400 space-y-2">
                    <div class="flex flex-wrap gap-x-4">
                      <span :if={s.postmark_bounce_id}>
                        <span class="font-medium">Bounce ID:</span> {s.postmark_bounce_id}
                      </span>
                      <span :if={s.postmark_inactive} class="font-medium">Inactive</span>
                      <span :if={s.can_activate} class="font-medium">Can reactivate</span>
                    </div>
                    <.input_with_clipboard
                      :if={s.details not in [nil, ""]}
                      id={"suppression-details-input-#{s.id}"}
                      name={"suppression-details-input-#{s.id}"}
                      label="Postmark details"
                      value={s.details}
                    />
                  </:menu>
                </.dropdown>
              </div>
            </.td>
          </:tbody>
        </.table>

        <div
          :if={@page.metadata.before || @page.metadata.after}
          class="flex justify-between items-center mt-4"
        >
          <.styled_link
            :if={@page.metadata.before}
            patch={
              ~p"/cs/email-suppressions?#{pagination_query(@reason, @search, before: @page.metadata.before)}"
            }
          >
            ← Previous
          </.styled_link>
          <div></div>
          <.styled_link
            :if={@page.metadata.after}
            patch={
              ~p"/cs/email-suppressions?#{pagination_query(@reason, @search, after: @page.metadata.after)}"
            }
          >
            Next →
          </.styled_link>
        </div>

        <p :if={@page.entries == []} class="text-sm text-gray-500 dark:text-gray-400">
          No suppressions found.
        </p>
      </div>
    </Layout.layout>
    """
  end

  defp has_postmark_details?(s) do
    not is_nil(s.postmark_bounce_id) or s.postmark_inactive or s.can_activate or
      s.details not in [nil, ""]
  end

  defp reason_strings, do: Enum.map(@reasons, &Atom.to_string/1)

  defp pagination_query(reason, search, cursor) do
    [reason: reason, search: search]
    |> Keyword.merge(cursor)
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
  end

  defp reactivated_by_label(%{reactivated_by: %{email: email}}), do: email
  defp reactivated_by_label(_suppression), do: "unknown"

  defp format_datetime(nil), do: "—"
  defp format_datetime(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")

  defp reason_label(:hard_bounce), do: "Hard bounce"
  defp reason_label(:bad_email_address), do: "Bad address"
  defp reason_label(:blocked), do: "Blocked"
  defp reason_label(:spam_complaint), do: "Spam complaint"
  defp reason_label(:spam_notification), do: "Spam notification"
  defp reason_label(:manual), do: "Manual"

  defp reason_color(:spam_complaint), do: :red
  defp reason_color(:spam_notification), do: :red
  defp reason_color(:hard_bounce), do: :red
  defp reason_color(:blocked), do: :red
  defp reason_color(:bad_email_address), do: :yellow
  defp reason_color(:manual), do: :gray
end
