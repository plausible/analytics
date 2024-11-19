defmodule PlausibleWeb.Api.ExternalStatsController.QuerySpecialMetricsTest do
  use PlausibleWeb.ConnCase

  setup [:create_user, :create_site, :create_api_key, :use_api_key]

  test "returns conversion_rate in a goal filtered custom prop breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview, pathname: "/blog/1", "meta.key": ["author"], "meta.value": ["Uku"]),
      build(:pageview, pathname: "/blog/2", "meta.key": ["author"], "meta.value": ["Uku"]),
      build(:pageview, pathname: "/blog/3", "meta.key": ["author"], "meta.value": ["Uku"]),
      build(:pageview, pathname: "/blog/1", "meta.key": ["author"], "meta.value": ["Marko"]),
      build(:pageview,
        pathname: "/blog/2",
        "meta.key": ["author"],
        "meta.value": ["Marko"],
        user_id: 1
      ),
      build(:pageview,
        pathname: "/blog/3",
        "meta.key": ["author"],
        "meta.value": ["Marko"],
        user_id: 1
      ),
      build(:pageview, pathname: "/blog"),
      build(:pageview, "meta.key": ["author"], "meta.value": ["Marko"]),
      build(:pageview)
    ])

    insert(:goal, %{site: site, page_path: "/blog**"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Visit /blog**"]]],
        "metrics" => ["visitors", "events", "conversion_rate"],
        "dimensions" => ["event:props:author"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["Uku"], "metrics" => [3, 3, 37.5]},
             %{"dimensions" => ["Marko"], "metrics" => [2, 3, 25.0]},
             %{"dimensions" => ["(none)"], "metrics" => [1, 1, 12.5]}
           ]
  end

  test "returns conversion_rate alone in a goal filtered custom prop breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:pageview, pathname: "/blog/1", "meta.key": ["author"], "meta.value": ["Uku"]),
      build(:pageview)
    ])

    insert(:goal, %{site: site, page_path: "/blog**"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate"],
        "date_range" => "all",
        "dimensions" => ["event:props:author"],
        "filters" => [["is", "event:goal", ["Visit /blog**"]]]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Uku"], "metrics" => [50]}
           ]
  end

  test "returns conversion_rate in a goal filtered event:page breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:event, pathname: "/en/register", name: "pageview"),
      build(:event, pathname: "/en/register", name: "Signup"),
      build(:event, pathname: "/en/register", name: "Signup"),
      build(:event, pathname: "/it/register", name: "Signup", user_id: 1),
      build(:event, pathname: "/it/register", name: "Signup", user_id: 1),
      build(:event, pathname: "/it/register", name: "pageview")
    ])

    insert(:goal, %{site: site, event_name: "Signup"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "dimensions" => ["event:page"],
        "filters" => [["is", "event:goal", ["Signup"]]],
        "metrics" => ["visitors", "events", "group_conversion_rate"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["/en/register"], "metrics" => [2, 2, 66.7]},
             %{"dimensions" => ["/it/register"], "metrics" => [1, 2, 50.0]}
           ]
  end

  test "returns conversion_rate alone in a goal filtered event:page breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:event, pathname: "/en/register", name: "pageview"),
      build(:event, pathname: "/en/register", name: "Signup")
    ])

    insert(:goal, %{site: site, event_name: "Signup"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "date_range" => "all",
        "filters" => [["is", "event:goal", ["Signup"]]],
        "metrics" => ["group_conversion_rate"],
        "dimensions" => ["event:page"]
      })

    assert json_response(conn, 200)["results"] == [
             %{"dimensions" => ["/en/register"], "metrics" => [50.0]}
           ]
  end

  test "returns conversion_rate in a multi-goal filtered visit:screen_size breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:event, screen_size: "Mobile", name: "pageview"),
      build(:event, screen_size: "Mobile", name: "AddToCart"),
      build(:event, screen_size: "Mobile", name: "AddToCart"),
      build(:event, screen_size: "Desktop", name: "AddToCart", user_id: 1),
      build(:event, screen_size: "Desktop", name: "Purchase", user_id: 1),
      build(:event, screen_size: "Desktop", name: "pageview")
    ])

    # Make sure that revenue goals are treated the same
    # way as regular custom event goals
    insert(:goal, %{site: site, event_name: "Purchase", currency: :EUR})
    insert(:goal, %{site: site, event_name: "AddToCart"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["visitors", "events", "group_conversion_rate"],
        "date_range" => "all",
        "dimensions" => ["visit:device"],
        "filters" => [["is", "event:goal", ["AddToCart", "Purchase"]]]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Mobile"], "metrics" => [2, 2, 66.7]},
             %{"dimensions" => ["Desktop"], "metrics" => [1, 2, 50]}
           ]
  end

  test "returns conversion_rate alone in a goal filtered visit:screen_size breakdown", %{
    conn: conn,
    site: site
  } do
    populate_stats(site, [
      build(:event, screen_size: "Mobile", name: "pageview"),
      build(:event, screen_size: "Mobile", name: "AddToCart")
    ])

    insert(:goal, %{site: site, event_name: "AddToCart"})

    conn =
      post(conn, "/api/v2/query", %{
        "site_id" => site.domain,
        "metrics" => ["conversion_rate"],
        "date_range" => "all",
        "dimensions" => ["visit:device"],
        "filters" => [["is", "event:goal", ["AddToCart"]]]
      })

    %{"results" => results} = json_response(conn, 200)

    assert results == [
             %{"dimensions" => ["Mobile"], "metrics" => [50]}
           ]
  end
end
