defmodule Swati.ToolsTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Repo
  alias Swati.Tools
  alias Swati.Tools.Tool

  test "ensure_tools inserts defaults and preserves existing risk" do
    scope = user_scope_fixture()

    {:ok, _tool} =
      Tools.upsert_tool(scope.tenant.id, %{
        name: "search",
        origin: "integration",
        risk: %{"financial" => "low"}
      })

    :ok = Tools.ensure_tools(scope.tenant.id, ["search", "send"], "integration")

    tool = Repo.get_by(Tool, tenant_id: scope.tenant.id, name: "search")
    inserted = Repo.get_by(Tool, tenant_id: scope.tenant.id, name: "send")

    assert tool.risk["financial"] == "low"
    assert inserted.origin == "integration"
    assert inserted.risk["access"] == "read"
  end
end
