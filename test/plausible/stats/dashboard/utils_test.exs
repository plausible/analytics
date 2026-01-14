defmodule Plausible.Stats.Dashboard.UtilsTest do
  use Plausible.DataCase
  import Plausible.Stats.Dashboard.Utils

  describe "page_external_link_fn_for/1" do
    @tag :ee_only
    test "returns nil for a consolidated site" do
      site = build(:site, consolidated: true)
      assert is_nil(page_external_link_fn_for(site))
    end

    test "returns a function returning a valid link for valid site" do
      site = build(:site, domain: "abc.com")
      fun = page_external_link_fn_for(site)
      assert fun.(%{dimensions: ["/some-page"]}) == "https://abc.com/some-page"
    end

    test "returns a function returning a valid link for site with subdomain" do
      site = build(:site, domain: "foo.abc.com")
      fun = page_external_link_fn_for(site)
      assert fun.(%{dimensions: ["/some-page"]}) == "https://foo.abc.com/some-page"
    end

    test "subfolder in site domain is stripped" do
      site = build(:site, domain: "abc.com/subfolder")
      fun = page_external_link_fn_for(site)

      assert fun.(%{dimensions: ["/subfolder/some-page"]}) ==
               "https://abc.com/subfolder/some-page"

      assert fun.(%{dimensions: ["/some-page"]}) == "https://abc.com/some-page"
    end

    test "handles internationalized domain names" do
      site = build(:site, domain: "é-1.com")
      fun = page_external_link_fn_for(site)
      assert fun.(%{dimensions: ["/some-page"]}) == "https://xn---1-9ia.com/some-page"
    end
  end
end
