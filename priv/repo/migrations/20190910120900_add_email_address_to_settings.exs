defmodule Plausible.Repo.Migrations.AddEmailAddressToSettings do
  use Ecto.Migration
  use Plausible.Repo
  alias Plausible.Site.EmailSettings

  def change do
    alter table(:email_settings) do
      add :email, :citext
    end

    flush()
    all = Repo.all(EmailSettings)

    for settings <- all do
      mem = Repo.get_by(Plausible.Site.Membership, site_id: settings.site_id) |> Repo.preload(:user)
      EmailSettings.changeset(settings, %{email: mem.user.email}) |> Repo.update!
    end

    alter table(:email_settings) do
      modify :email, :citext, null: false
    end
  end
end
