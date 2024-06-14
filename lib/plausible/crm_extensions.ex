defmodule Plausible.CrmExtensions do
  @moduledoc """
  Extensions for Kaffy CRM
  """

  use Plausible

  on_ee do
    def javascripts(%{assigns: %{context: "auth", resource: "user", entry: %{} = user}}) do
      Enum.map(
        [
          """
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
          """
        ],
        &Phoenix.HTML.raw/1
      )
    end
  end

  def javascripts(_) do
    []
  end
end
