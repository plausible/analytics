defmodule Plausible.Google.GA4.APITest do
  use Plausible.DataCase, async: true

  import Mox

  alias Plausible.Google.GA4

  setup :verify_on_exit!

  describe "list_properties/1" do
    test "returns list of properties grouped by accounts" do
      result = Jason.decode!(File.read!("fixture/ga4_list_properties.json"))

      expect(Plausible.HTTPClient.Mock, :get, fn _url, _opts ->
        {:ok, %Finch.Response{status: 200, body: result}}
      end)

      assert {:ok, accounts} = GA4.API.list_properties("some_access_token")

      assert [
               {"account.one (accounts/28425178)",
                [{"account.one - GA4 (properties/428685906)", "properties/428685906"}]},
               {"Demo Account (accounts/54516992)",
                [
                  {"GA4 - Flood-It! (properties/153293282)", "properties/153293282"},
                  {"GA4 - Google Merch Shop (properties/213025502)", "properties/213025502"}
                ]}
             ] = accounts
    end

    test "handles empty response properly" do
      expect(Plausible.HTTPClient.Mock, :get, fn _url, _opts ->
        {:ok, %Finch.Response{status: 200, body: %{}}}
      end)

      assert {:ok, []} = GA4.API.list_properties("some_access_token")
    end
  end

  describe "get_property/2" do
    test "returns tuple consisting of display name and value of a property" do
      result = Jason.decode!(File.read!("fixture/ga4_get_property.json"))

      expect(Plausible.HTTPClient.Mock, :get, fn _url, _opts ->
        {:ok, %Finch.Response{status: 200, body: result}}
      end)

      assert {:ok,
              %{name: "account.one - GA4 (properties/428685444)", id: "properties/428685444"}} =
               GA4.API.get_property("some_access_token", "properties/428685444")
    end
  end

  describe "get_analytics_start_date/2" do
    test "returns stats start date for a given property" do
      result = Jason.decode!(File.read!("fixture/ga4_start_date.json"))

      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _body ->
        {:ok, %Finch.Response{status: 200, body: result}}
      end)

      assert {:ok, ~D[2024-02-22]} =
               GA4.API.get_analytics_start_date("some_access_token", "properties/153293282")
    end
  end

  describe "get_analytics_end_date/2" do
    test "returns stats end date for a given property" do
      result = Jason.decode!(File.read!("fixture/ga4_end_date.json"))

      expect(Plausible.HTTPClient.Mock, :post, fn _url, _headers, _body ->
        {:ok, %Finch.Response{status: 200, body: result}}
      end)

      assert {:ok, ~D[2024-03-02]} =
               GA4.API.get_analytics_end_date("some_access_token", "properties/153293282")
    end
  end
end
