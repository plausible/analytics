defmodule Plausible.ClickhouseRepo.Migrations.HostnamesInSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions_v2) do
      add(:entry_page_hostname, :string)
      add(:exit_page_hostname, :string)
    end
  end
end
