defmodule Swati.Agents.PromptSectionsTest do
  use ExUnit.Case, async: true

  alias Swati.Agents.PromptSections

  describe "default_sections/0" do
    test "returns 6 sections with correct types" do
      config = PromptSections.default_sections()
      assert config["version"] == 1
      sections = config["sections"]
      assert length(sections) == 6

      types = Enum.map(sections, & &1["type"])

      assert types == [
               "tenant_identity",
               "tenant_brand_voice",
               "tenant_boundaries",
               "tenant_escalation_map",
               "tenant_workflows",
               "custom"
             ]

      # All enabled by default
      assert Enum.all?(sections, & &1["enabled"])

      # Tenant sections are locked, custom is not
      locked_status = Enum.map(sections, & &1["locked"])
      assert locked_status == [true, true, true, true, true, false]
    end
  end

  describe "migrate_from_instructions/1" do
    test "converts nil to default sections" do
      config = PromptSections.migrate_from_instructions(nil)
      assert config["version"] == 1
      assert length(config["sections"]) == 6
    end

    test "converts instructions text into migrated custom section" do
      config = PromptSections.migrate_from_instructions("You are a helpful assistant.")
      sections = config["sections"]

      custom = Enum.find(sections, &(&1["type"] == "custom"))
      assert custom["title"] == "Instructions (migrated)"
      assert custom["content"] == "You are a helpful assistant."
      assert custom["locked"] == false
      assert custom["enabled"] == true
    end

    test "keeps all tenant sections" do
      config = PromptSections.migrate_from_instructions("test")
      tenant_sections = Enum.filter(config["sections"], & &1["locked"])
      assert length(tenant_sections) == 5
    end
  end

  describe "render_flat/2" do
    setup do
      tenant = %{
        business_identity: "We are Acme Corp",
        business_brand_voice: "Professional and friendly",
        business_operating_boundaries: "9am-5pm EST",
        business_escalation_map: "Level 1: Support, Level 2: Manager",
        business_top_workflows: "1. Order lookup\n2. Returns"
      }

      %{tenant: tenant}
    end

    test "renders enabled sections with headers", %{tenant: tenant} do
      config = %{
        "version" => 1,
        "sections" => [
          %{
            "id" => "s1",
            "type" => "tenant_identity",
            "title" => "Business Identity",
            "content" => nil,
            "enabled" => true,
            "locked" => true
          },
          %{
            "id" => "s2",
            "type" => "custom",
            "title" => "Core Instructions",
            "content" => "Be helpful.",
            "enabled" => true,
            "locked" => false
          }
        ]
      }

      result = PromptSections.render_flat(config, tenant)
      assert result =~ "### Business Identity"
      assert result =~ "We are Acme Corp"
      assert result =~ "### Core Instructions"
      assert result =~ "Be helpful."
    end

    test "skips disabled sections", %{tenant: tenant} do
      config = %{
        "version" => 1,
        "sections" => [
          %{
            "id" => "s1",
            "type" => "tenant_identity",
            "title" => "Business Identity",
            "content" => nil,
            "enabled" => false,
            "locked" => true
          },
          %{
            "id" => "s2",
            "type" => "custom",
            "title" => "Core",
            "content" => "Hello",
            "enabled" => true,
            "locked" => false
          }
        ]
      }

      result = PromptSections.render_flat(config, tenant)
      refute result =~ "Business Identity"
      assert result =~ "Hello"
    end

    test "skips tenant sections with empty content", %{tenant: _tenant} do
      empty_tenant = %{
        business_identity: "",
        business_brand_voice: "",
        business_operating_boundaries: "",
        business_escalation_map: "",
        business_top_workflows: ""
      }

      config = %{
        "version" => 1,
        "sections" => [
          %{
            "id" => "s1",
            "type" => "tenant_identity",
            "title" => "Business Identity",
            "content" => nil,
            "enabled" => true,
            "locked" => true
          }
        ]
      }

      result = PromptSections.render_flat(config, empty_tenant)
      assert result == ""
    end

    test "returns empty string for nil config" do
      assert PromptSections.render_flat(nil, %{}) == ""
    end

    test "respects section ordering", %{tenant: tenant} do
      config = %{
        "version" => 1,
        "sections" => [
          %{
            "id" => "s1",
            "type" => "custom",
            "title" => "First",
            "content" => "AAA",
            "enabled" => true,
            "locked" => false
          },
          %{
            "id" => "s2",
            "type" => "tenant_identity",
            "title" => "Business Identity",
            "content" => nil,
            "enabled" => true,
            "locked" => true
          }
        ]
      }

      result = PromptSections.render_flat(config, tenant)
      first_pos = :binary.match(result, "### First") |> elem(0)
      second_pos = :binary.match(result, "### Business Identity") |> elem(0)
      assert first_pos < second_pos
    end
  end

  describe "reorder/2" do
    test "reorders sections by ID list" do
      config = %{
        "version" => 1,
        "sections" => [
          %{"id" => "a", "type" => "custom"},
          %{"id" => "b", "type" => "custom"},
          %{"id" => "c", "type" => "custom"}
        ]
      }

      result = PromptSections.reorder(config, ["c", "a", "b"])
      ids = Enum.map(result["sections"], & &1["id"])
      assert ids == ["c", "a", "b"]
    end

    test "appends sections not in order list" do
      config = %{
        "version" => 1,
        "sections" => [
          %{"id" => "a", "type" => "custom"},
          %{"id" => "b", "type" => "custom"},
          %{"id" => "c", "type" => "custom"}
        ]
      }

      result = PromptSections.reorder(config, ["b"])
      ids = Enum.map(result["sections"], & &1["id"])
      assert ids == ["b", "a", "c"]
    end
  end

  describe "toggle_section/2" do
    test "toggles section enabled state" do
      config = %{
        "version" => 1,
        "sections" => [
          %{"id" => "s1", "enabled" => true, "type" => "custom"}
        ]
      }

      result = PromptSections.toggle_section(config, "s1")
      assert hd(result["sections"])["enabled"] == false

      result2 = PromptSections.toggle_section(result, "s1")
      assert hd(result2["sections"])["enabled"] == true
    end
  end

  describe "update_section_content/3" do
    test "updates content for custom sections" do
      config = %{
        "version" => 1,
        "sections" => [
          %{"id" => "s1", "content" => "old", "locked" => false, "type" => "custom"}
        ]
      }

      result = PromptSections.update_section_content(config, "s1", "new content")
      assert hd(result["sections"])["content"] == "new content"
    end

    test "does not update locked sections" do
      config = %{
        "version" => 1,
        "sections" => [
          %{"id" => "s1", "content" => nil, "locked" => true, "type" => "tenant_identity"}
        ]
      }

      result = PromptSections.update_section_content(config, "s1", "hacked")
      assert hd(result["sections"])["content"] == nil
    end
  end

  describe "update_section_title/3" do
    test "updates title for custom sections" do
      config = %{
        "version" => 1,
        "sections" => [
          %{"id" => "s1", "title" => "Old", "locked" => false, "type" => "custom"}
        ]
      }

      result = PromptSections.update_section_title(config, "s1", "New Title")
      assert hd(result["sections"])["title"] == "New Title"
    end
  end

  describe "remove_section/2" do
    test "removes custom section" do
      config = %{
        "version" => 1,
        "sections" => [
          %{"id" => "s1", "locked" => false, "type" => "custom"},
          %{"id" => "s2", "locked" => true, "type" => "tenant_identity"}
        ]
      }

      result = PromptSections.remove_section(config, "s1")
      assert length(result["sections"]) == 1
      assert hd(result["sections"])["id"] == "s2"
    end

    test "does not remove locked sections" do
      config = %{
        "version" => 1,
        "sections" => [
          %{"id" => "s1", "locked" => true, "type" => "tenant_identity"}
        ]
      }

      result = PromptSections.remove_section(config, "s1")
      assert length(result["sections"]) == 1
    end
  end

  describe "new_custom_section/2" do
    test "creates a new custom section with defaults" do
      section = PromptSections.new_custom_section()
      assert section["type"] == "custom"
      assert section["locked"] == false
      assert section["enabled"] == true
      assert String.starts_with?(section["id"], "sec_")
    end

    test "accepts custom title and content" do
      section = PromptSections.new_custom_section("My Section", "My content")
      assert section["title"] == "My Section"
      assert section["content"] == "My content"
    end
  end
end
