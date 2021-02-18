defmodule Plausible.PaddleApi.Mock do
  def get_subscription(_) do
    {:ok,
     %{
       "next_payment" => %{
         "date" => "2019-07-10",
         "amount" => 6
       },
       "last_payment" => %{
         "date" => "2019-06-10",
         "amount" => 6
       }
     }}
  end

  def update_subscription(_, %{plan_id: new_plan_id}) do
    new_plan_id = String.to_integer(new_plan_id)

    {:ok,
     %{
       "plan_id" => new_plan_id,
       "next_payment" => %{
         "date" => "2019-07-10",
         "amount" => 6
       }
     }}
  end
end
