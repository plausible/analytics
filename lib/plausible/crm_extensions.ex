defmodule Plausible.CrmExtensions do
  @moduledoc """
  Extensions for Kaffy CRM
  """

  use Plausible

  # Kaffy uses String.to_existing_atom when listing params
  @custom_search :custom_search

  on_ee do
    def javascripts(%{assigns: %{context: "auth", resource: "user", entry: %{} = user}}) do
      [
        Phoenix.HTML.raw("""
        <script type="text/javascript">
          (async () => {
            const response = await fetch("/crm/auth/user/#{user.id}/usage?embed=true")
            const usageHTML = await response.text()
            const cardBody = document.querySelector(".card-body")
            if (cardBody) {
              const usageDOM = document.createElement("div")
              usageDOM.innerHTML = usageHTML
              cardBody.prepend(usageDOM)
            }
          })()
        </script>
        """)
      ]
    end

    def javascripts(%{assigns: %{context: "sites", resource: "site", entry: %{domain: domain}}}) do
      base_url = PlausibleWeb.Endpoint.url()

      [
        Phoenix.HTML.raw("""
        <script type="text/javascript">
          (() => {
            const cardBody = document.querySelector(".card-body")
            if (cardBody) {
              const buttonDOM = document.createElement("div")
              buttonDOM.className = "mb-3 w-full text-right"
              buttonDOM.innerHTML = '<div><a class="btn btn-outline-primary" href="#{base_url <> "/" <> URI.encode_www_form(domain)}" target="_blank">Open Dashboard</a></div>'
              cardBody.prepend(buttonDOM)
            }
          })()
        </script>
        """)
      ]
    end

    def javascripts(%{assigns: %{context: context}})
        when context in ["sites", "billing"] do

      [
        Phoenix.HTML.raw("""
        <script type="text/javascript">
          (() => {
            const publicField = document.querySelector("#kaffy-search-field")
            const searchForm = document.querySelector("#kaffy-filters-form")
            const searchField = document.querySelector("#kaffy-filter-search")

            if (publicField && searchForm && searchField) {
              publicField.name = "#{@custom_search}"
              searchField.name = "#{@custom_search}"

              const params = new URLSearchParams(window.location.search)
              publicField.value = params.get("#{@custom_search}")

              const searchInput = document.createElement("input")
              searchInput.name = "search"
              searchInput.type = "hidden"
              searchInput.value = ""

              searchForm.appendChild(searchInput)
            }
          })()
        </script>
        """)
      ]
    end

    def javascripts(%{assigns: %{context: "billing", resource: "enterprise_plan", changeset: %{}}}) do
      [
        Phoenix.HTML.raw("""
        <script type="text/javascript">
          (() => {
            const monthlyPageviewLimitField = document.getElementById("enterprise_plan_monthly_pageview_limit")

            monthlyPageviewLimitField.type = "input"
            monthlyPageviewLimitField.addEventListener("keyup", numberFormatCallback)
            monthlyPageviewLimitField.addEventListener("change", numberFormatCallback)

            monthlyPageviewLimitField.dispatchEvent(new Event("change"))

            function numberFormatCallback(e) {
              const numeric = Number(e.target.value.replace(/[^0-9]/g, ''))
              const value = numeric > 0 ? new Intl.NumberFormat("en-GB").format(numeric) : ''
              e.target.value = value
            }
          })()
        </script>
        """),
        Phoenix.HTML.raw("""
        <script type="text/javascript">
          (async () => {
            const CHECK_INTERVAL = 300
            const userIdField = document.getElementById("enterprise_plan_user_id") || document.getElementById("user_id")
            let planRequest
            let lastValue = Number(userIdField.value)
            let currentValue = lastValue

            setTimeout(prefillCallback, CHECK_INTERVAL)

            async function prefillCallback() {
              currentValue = Number(userIdField.value)
              if (Number.isInteger(currentValue)
                    && currentValue > 0
                    && currentValue != lastValue
                    && !planRequest) {
                planRequest = await fetch("/crm/billing/user/" + currentValue + "/current_plan")
                const result = await planRequest.json()

                fillForm(result)

                lastValue = currentValue
                planRequest = null
              }

              setTimeout(prefillCallback, CHECK_INTERVAL)
            }

            function fillForm(result) {
              [
                'billing_interval',
                'monthly_pageview_limit',
                'site_limit',
                'team_member_limit',
                'hourly_api_request_limit'
              ].forEach(name => {
                const prefillValue = result[name] || ""
                const field = document.getElementById('enterprise_plan_' + name)

                field.value = prefillValue
                field.dispatchEvent(new Event("change"))
              });

              ['stats_api', 'props', 'funnels', 'revenue_goals'].forEach(feature => {
                const checked = result.features.includes(feature)
                document.getElementById('enterprise_plan_features_' + feature).checked = checked
              });
            }
          })()
        </script>
        """)
      ]
    end
  end

  def javascripts(_) do
    []
  end
end
