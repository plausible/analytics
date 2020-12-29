defmodule Plausible.Google.Api.Mock do
  def fetch_stats(_auth, _query, _limit) do
    {:ok,
     [
       %{"name" => "simple web analytics", "count" => 6},
       %{"name" => "open-source analytics", "count" => 2}
     ]}
  end
end
