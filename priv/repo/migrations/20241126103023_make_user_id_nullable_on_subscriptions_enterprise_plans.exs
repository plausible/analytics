defmodule Plausible.Repo.Migrations.MakeUserIdNullableOnSubscriptionsEnterprisePlans do
  use Ecto.Migration

  def change do
    execute """
            alter table subscriptions alter column user_id drop not null
            """,
            """
            alter table subscriptions alter column user_id set not null
            """

    execute """
            alter table enterprise_plans alter column user_id drop not null
            """,
            """
            alter table enterprise_plans alter column user_id set not null
            """
  end
end
