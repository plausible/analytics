defmodule Plausible.ClickhouseRepo.Migrations.AddSampleBy do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE events MODIFY SAMPLE BY user_id"
    execute "ALTER TABLE sessions MODIFY SAMPLE BY user_id"
  end
end
