defmodule Plausible.Repo.Migrations.CreatePlansTable do
  use Ecto.Migration

  def change do
    if !Application.get_env(:plausible, :is_selfhost) do
      create table(:plans) do
        add :generation, :integer, null: false
        add :kind, :string, null: false
        add :features, {:array, :string}, null: false
        add :monthly_pageview_limit, :integer, null: false
        add :site_limit, :integer, null: false
        add :team_member_limit, :integer, null: false
        add :volume, :string, null: false
        add :monthly_cost, :decimal, null: true
        add :monthly_product_id, :string, null: true
        add :yearly_cost, :decimal, null: true
        add :yearly_product_id, :string, null: true
      end
    end
  end
end
