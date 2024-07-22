defmodule Plausible.Google.API.Mock do
  @moduledoc """
  Mock of API to Google services.
  """

  def fetch_stats(_auth, _query, _pagination, _search) do
    {:ok,
     [
       %{"name" => "simple web analytics", "count" => 6},
       %{"name" => "open-source analytics", "count" => 2}
     ]}
  end
end
