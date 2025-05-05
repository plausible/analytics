defmodule Plausible.CrmExtensions do
  @moduledoc """
  Extensions for Kaffy CRM
  """

  use Plausible

  on_ee do
    # Kaffy uses String.to_existing_atom when listing params
    @custom_search :custom_search

    def javascripts(%{assigns: %{context: "teams", resource: "team", entry: %{} = team}}) do
      [
        Phoenix.HTML.raw("""
        <script type="text/javascript">
          (async () => {
            const response = await fetch("/crm/teams/team/#{team.id}/usage?embed=true")
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

    def javascripts(%{assigns: %{context: "auth", resource: "user", entry: %{} = user}}) do
      [
        Phoenix.HTML.raw("""
        <script type="text/javascript">
          (async () => {
            const response = await fetch("/crm/auth/user/#{user.id}/info")
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

    def javascripts(%{
          assigns: %{context: "billing", resource: "enterprise_plan", changeset: %{}}
        }) do
      [
        Phoenix.HTML.raw("""
        <script type="text/javascript">
          (() => {
            const statsFeature = document.querySelector(`input[type=checkbox][value=stats_api]`)
            const sitesFeature = document.querySelector(`input[type=checkbox][value=sites_api]`)

            statsFeature.addEventListener("change", () => {
              if (!statsFeature.checked) {
                sitesFeature.checked = false
              }
              return true;
            })

            sitesFeature.addEventListener("change", () => {
              if (sitesFeature.checked) {
                statsFeature.checked = true
              }
              return true;
            })
          })()
        </script>
        """),
        Phoenix.HTML.raw("""
        <script type="text/javascript">
          (async () => {
            const CHECK_INTERVAL = 300

            const teamPicker = document.querySelector("#pick-raw-resource")
            if (teamPicker) {
              teamPicker.style.display = "none";
            }
            const teamIdField = document.querySelector("#enterprise_plan_team_id") ||
                            document.querySelector("#team_id")
            const teamIdLabel = document.querySelector("label[for=enterprise_plan_team_id]")
            const dataList = document.createElement("datalist")
            dataList.id = "team-choices"
            teamIdField.after(dataList)
            teamIdField.setAttribute("list", "team-choices")
            teamIdField.setAttribute("type", "text")
            teamIdField.setAttribute("autocomplete", "off")
            const labelSpan = document.createElement("span")
            teamIdLabel.appendChild(labelSpan)

            let updateAction;

            const updateLabel = async (id) => {
              id = Number(id)

              if (!isNaN(id) && id > 0) {
                const response = await fetch(`/crm/billing/search/team-by-id/${id}`)
                labelSpan.innerHTML = ` <i>(${await response.text()})</i>`
              }
            }

            const updateSearch = async () => {
              const search = teamIdField.value

              updateLabel(search)

              const response = await fetch("/crm/billing/search/team", {
                headers: { "Content-Type": "application/json" },
                method: "POST",
                body: JSON.stringify({ search: search })
              })

              const list = await response.json()

              const options =
                list.map(([label, value]) => {
                  const option = document.createElement("option")
                  option.setAttribute("label", label)
                  option.textContent = value

                  return option
                })

              dataList.replaceChildren(...options)
            }

            updateLabel(teamIdField.value)

            teamIdField.addEventListener("input", async (e) => {
              if (updateAction) {
                clearTimeout(updateAction)
                updateAction = null
              }

              updateAction = setTimeout(() => updateSearch(), CHECK_INTERVAL)
            })
          })()
        </script>
        """),
        Phoenix.HTML.raw("""
        <script type="text/javascript">
          (() => {
            const fields = ["monthly_pageview_limit", "site_limit"].map(p => document.getElementById(`enterprise_plan_${p}`))
            fields.forEach(field => {
              field.type = "input"
              field.addEventListener("keyup", numberFormatCallback)
              field.addEventListener("change", numberFormatCallback)

              field.dispatchEvent(new Event("change"))
            })

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
            const teamIdField = document.getElementById("enterprise_plan_team_id") || document.getElementById("team_id")
            let planRequest
            let lastValue = Number(teamIdField.value)
            let currentValue = lastValue

            setTimeout(prefillCallback, CHECK_INTERVAL)

            async function prefillCallback() {
              currentValue = Number(teamIdField.value)
              if (Number.isInteger(currentValue)
                    && currentValue > 0
                    && currentValue != lastValue
                    && !planRequest) {
                planRequest = await fetch("/crm/billing/team/" + currentValue + "/current_plan")
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

              ['stats_api', 'props', 'funnels', 'revenue_goals', 'site_segments'].forEach(feature => {
                const checked = result.features.includes(feature)
                const field = document.querySelector(`input[type=checkbox][value=${feature}]`)
                if (field) {
                  field.checked = checked
                }
              });
            }
          })()
        </script>
        """)
      ]
    end

    def javascripts(%{assigns: %{context: context}})
        when context in ["teams", "sites", "billing"] do
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
  end

  def javascripts(_) do
    []
  end
end
