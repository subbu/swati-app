defmodule Swati.Tenancy.AboutBusinessTest do
  use Swati.DataCase

  import Swati.AccountsFixtures

  alias Swati.Repo
  alias Swati.Tenancy

  test "change_about_business/2 enforces max lengths" do
    tenant = tenant_fixture()

    changeset =
      Tenancy.change_about_business(tenant, %{
        "business_identity" => String.duplicate("a", 501),
        "business_brand_voice" => String.duplicate("a", 501),
        "business_operating_boundaries" => String.duplicate("a", 501),
        "business_escalation_map" => String.duplicate("a", 401),
        "business_top_workflows" => String.duplicate("a", 1201)
      })

    refute changeset.valid?

    assert "should be at most 500 character(s)" in errors_on(changeset).business_identity
    assert "should be at most 500 character(s)" in errors_on(changeset).business_brand_voice

    assert "should be at most 500 character(s)" in errors_on(changeset).business_operating_boundaries

    assert "should be at most 400 character(s)" in errors_on(changeset).business_escalation_map
    assert "should be at most 1200 character(s)" in errors_on(changeset).business_top_workflows
  end

  test "update_about_business/2 persists tenant-level about business fields" do
    tenant = tenant_fixture()

    assert {:ok, updated} =
             Tenancy.update_about_business(tenant, %{
               "business_identity" => "Acme Health, Austin service area, in-home physiotherapy.",
               "business_brand_voice" => "Friendly, precise, confidence-building.",
               "business_operating_boundaries" =>
                 "Can confirm appointments; escalate prescriptions. Never ask OTP/password.",
               "business_escalation_map" => "Billing -> Priya\nTech -> Hari\nMedical -> doctor",
               "business_top_workflows" => "1) Booking\n- collect need\n- collect time\n- confirm"
             })

    reloaded = Repo.get!(Swati.Tenancy.Tenant, updated.id)

    assert reloaded.business_identity =~ "Acme Health"
    assert reloaded.business_brand_voice =~ "Friendly"
    assert reloaded.business_operating_boundaries =~ "Never ask OTP/password"
    assert reloaded.business_escalation_map =~ "Billing -> Priya"
    assert reloaded.business_top_workflows =~ "Booking"
  end

  defp tenant_fixture do
    user_fixture()
    |> Repo.preload(:tenant)
    |> Map.fetch!(:tenant)
  end
end
