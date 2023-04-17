defmodule PlausibleWeb.Api.FunnelsController do
  use PlausibleWeb, :controller

  def show(conn, _params) do
    json(conn, %{
      name: "Signup Funnel",
      conversion_rate: "38%",
      steps: [
        %{
          label: "Signup",
          visitors: 31,
          complete_percentage: "100%",
          dropoff: 0,
          dropoff_percentage: "61%"
        },
        %{
          label: "Second goal",
          visitors: 12,
          complete_percentage: "38%",
          dropoff: 19,
          dropoff_percentage: "61%"
        }
      ]
    })
  end
end
