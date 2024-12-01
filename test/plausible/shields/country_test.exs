defmodule Plausible.Shields.CountryTest do
  use Plausible.DataCase
  import Plausible.Shields

  setup do
    site = insert(:site)
    {:ok, %{site: site}}
  end

  describe "add_country_rule/2" do
    test "no input", %{site: site} do
      assert {:error, changeset} = add_country_rule(site, %{})
      assert changeset.errors == [country_code: {"can't be blank", [validation: :required]}]
      refute changeset.valid?
    end

    test "unsupported country", %{site: site} do
      assert {:error, changeset} = add_country_rule(site, %{"country_code" => "0X"})
      assert changeset.errors == [country_code: {"is invalid", []}]
      refute changeset.valid?
    end

    test "incorrect country format", %{site: site} do
      assert {:error, changeset} = add_country_rule(site, %{"country_code" => "Germany"})

      assert changeset.errors ==
               [
                 {:country_code, {"is invalid", []}},
                 {:country_code,
                  {"should be %{count} character(s)",
                   [count: 2, validation: :length, kind: :is, type: :string]}}
               ]

      refute changeset.valid?
    end

    test "double insert", %{site: site} do
      assert {:ok, _} = add_country_rule(site, %{"country_code" => "EE"})
      assert {:error, changeset} = add_country_rule(site, %{"country_code" => "EE"})
      refute changeset.valid?

      assert changeset.errors == [
               country_code:
                 {"has already been taken",
                  [
                    {:constraint, :unique},
                    {:constraint_name, "shield_rules_country_site_id_country_code_index"}
                  ]}
             ]
    end

    test "over limit", %{site: site} do
      country_codes =
        Location.Country.all()
        |> Enum.take(Plausible.Shields.maximum_country_rules())
        |> Enum.map(& &1.alpha_2)

      for cc <- country_codes do
        assert {:ok, _} =
                 add_country_rule(site, %{"country_code" => cc})
      end

      assert count_country_rules(site) == maximum_country_rules()

      assert {:error, changeset} =
               add_country_rule(site, %{"country_code" => "US"})

      refute changeset.valid?
      assert changeset.errors == [country_code: {"maximum reached", []}]
    end

    test "with added_by", %{site: site} do
      assert {:ok, rule} =
               add_country_rule(site, %{"country_code" => "EE"},
                 added_by: build(:user, name: "Joe", email: "joe@example.com")
               )

      assert rule.added_by == "Joe <joe@example.com>"
    end
  end

  describe "remove_country_rule/2" do
    test "is idempotent", %{site: site} do
      {:ok, rule} = add_country_rule(site, %{"country_code" => "EE"})
      assert remove_country_rule(site, rule.id) == :ok
      refute Repo.get(Plausible.Shield.CountryRule, rule.id)
      assert remove_country_rule(site, rule.id) == :ok
    end
  end

  describe "list_country_rules/1" do
    test "empty", %{site: site} do
      assert(list_country_rules(site) == [])
    end

    @tag :slow
    test "many", %{site: site} do
      {:ok, r1} = add_country_rule(site, %{"country_code" => "EE"})
      :timer.sleep(1000)
      {:ok, r2} = add_country_rule(site, %{"country_code" => "PL"})
      assert [^r2, ^r1] = list_country_rules(site)
    end
  end

  describe "count_country_rules/1" do
    test "counts", %{site: site} do
      assert count_country_rules(site) == 0
      {:ok, _} = add_country_rule(site, %{"country_code" => "EE"})
      assert count_country_rules(site) == 1
      {:ok, _} = add_country_rule(site, %{"country_code" => "PL"})
      assert count_country_rules(site) == 2
    end
  end

  describe "Country Rules" do
    test "end to end", %{site: site} do
      site2 = insert(:site)

      assert count_country_rules(site.id) == 0
      assert list_country_rules(site.id) == []

      assert {:ok, rule} =
               add_country_rule(site.id, %{"country_code" => "EE"})

      add_country_rule(site2, %{"country_code" => "PL"})

      assert count_country_rules(site) == 1
      assert [^rule] = list_country_rules(site)
      assert rule.country_code == "EE"
      assert rule.action == :deny
      refute rule.from_cache?
      assert country_blocked?(site, "ee")
      refute country_blocked?(site, "xx")
    end
  end
end
