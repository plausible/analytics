defmodule Plausible.PaddleApi.Mock do
  def get_subscription(_) do
    {:ok, %{
      "next_payment" => %{
        "date" => "2019-07-10",
        "amount" => 6
      }
    }}
  end
end
