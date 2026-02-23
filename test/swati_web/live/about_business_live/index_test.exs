defmodule SwatiWeb.AboutBusinessLive.IndexTest do
  use SwatiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swati.AccountsFixtures

  alias Swati.Repo
  alias Swati.Tenancy.Tenant

  test "renders about business form in settings sidebar route", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/settings/about-business")

    assert has_element?(view, "#about-business-form")
    assert has_element?(view, "textarea[name='about_business[business_identity]']")
    assert has_element?(view, "textarea[name='about_business[business_top_workflows]']")
  end

  test "saves tenant-level about business content", %{conn: conn} do
    user = user_fixture()
    tenant_id = Repo.preload(user, :tenant).tenant.id

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/settings/about-business")

    params = %{
      "business_identity" => "North Star Clinic, Austin. Monthly care plans.",
      "business_brand_voice" => "Friendly, crisp, and factual.",
      "business_operating_boundaries" => "Never ask for OTP/password. Escalate billing disputes.",
      "business_escalation_map" => "Billing -> Priya\nTech -> Hari\nMedical -> doctor",
      "business_top_workflows" => "Booking:\n1. Capture need\n2. Confirm slot\n3. Confirm details"
    }

    html =
      view
      |> form("#about-business-form", about_business: params)
      |> render_submit()

    assert html =~ "About business updated."

    tenant = Repo.get!(Tenant, tenant_id)
    assert tenant.business_identity == params["business_identity"]
    assert tenant.business_brand_voice == params["business_brand_voice"]
    assert tenant.business_operating_boundaries == params["business_operating_boundaries"]
    assert tenant.business_escalation_map == params["business_escalation_map"]
    assert tenant.business_top_workflows == params["business_top_workflows"]
  end

  test "shows validation error for identity over 500 chars", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/settings/about-business")

    html =
      view
      |> form("#about-business-form",
        about_business: %{
          "business_identity" => String.duplicate("a", 501)
        }
      )
      |> render_change()

    assert html =~ "should be at most 500 character(s)"
  end
end
