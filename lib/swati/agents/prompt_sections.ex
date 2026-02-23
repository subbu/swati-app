defmodule Swati.Agents.PromptSections do
  @moduledoc """
  Manages structured prompt sections for agents.

  Sections are stored as a JSONB map with a version and ordered list.
  Tenant sections pull content from the tenant at runtime; custom sections
  store content inline.
  """

  @tenant_section_types %{
    "tenant_identity" => %{title: "Business Identity", field: :business_identity},
    "tenant_brand_voice" => %{title: "Brand Voice", field: :business_brand_voice},
    "tenant_boundaries" => %{title: "Operating Boundaries", field: :business_operating_boundaries},
    "tenant_escalation_map" => %{title: "Escalation Map", field: :business_escalation_map},
    "tenant_workflows" => %{title: "Top Workflows", field: :business_top_workflows}
  }

  def tenant_section_types, do: @tenant_section_types

  def default_sections do
    %{
      "version" => 1,
      "sections" => [
        %{
          "id" => generate_id(),
          "type" => "tenant_identity",
          "title" => "Business Identity",
          "content" => nil,
          "enabled" => true,
          "locked" => true
        },
        %{
          "id" => generate_id(),
          "type" => "tenant_brand_voice",
          "title" => "Brand Voice",
          "content" => nil,
          "enabled" => true,
          "locked" => true
        },
        %{
          "id" => generate_id(),
          "type" => "tenant_boundaries",
          "title" => "Operating Boundaries",
          "content" => nil,
          "enabled" => true,
          "locked" => true
        },
        %{
          "id" => generate_id(),
          "type" => "tenant_escalation_map",
          "title" => "Escalation Map",
          "content" => nil,
          "enabled" => true,
          "locked" => true
        },
        %{
          "id" => generate_id(),
          "type" => "tenant_workflows",
          "title" => "Top Workflows",
          "content" => nil,
          "enabled" => true,
          "locked" => true
        },
        %{
          "id" => generate_id(),
          "type" => "custom",
          "title" => "Core Instructions",
          "content" => "",
          "enabled" => true,
          "locked" => false
        }
      ]
    }
  end

  def migrate_from_instructions(nil), do: default_sections()

  def migrate_from_instructions(instructions) when is_binary(instructions) do
    sections = default_sections()
    custom_id = generate_id()

    migrated_section = %{
      "id" => custom_id,
      "type" => "custom",
      "title" => "Instructions (migrated)",
      "content" => instructions,
      "enabled" => true,
      "locked" => false
    }

    # Replace the default "Core Instructions" custom section with the migrated one
    updated_sections =
      sections["sections"]
      |> Enum.reject(fn s -> s["type"] == "custom" end)
      |> Kernel.++([migrated_section])

    %{sections | "sections" => updated_sections}
  end

  def render_flat(nil, _tenant), do: ""

  def render_flat(%{"sections" => sections}, tenant) when is_list(sections) do
    sections
    |> Enum.filter(fn s -> s["enabled"] == true end)
    |> Enum.map(fn section -> render_section(section, tenant) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(String.trim(&1) == ""))
    |> Enum.join("\n\n")
  end

  def render_flat(_sections, _tenant), do: ""

  @doc """
  Renders sections as safe HTML for the live preview panel.
  Converts ### headers, **bold**, and - list items to HTML.
  """
  def render_preview_html(sections, tenant) do
    render_flat(sections, tenant)
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.split("\n")
    |> Enum.map(fn line ->
      cond do
        Regex.match?(~r/^\#{2,3}\s/, line) ->
          title = String.replace(line, ~r/^\#{2,3}\s+/, "")
          ~s(<h3 class="text-xs font-semibold text-base-content uppercase tracking-wider mt-4 first:mt-0 mb-1.5">#{title}</h3>)

        String.trim(line) in ["---", "***", "___"] ->
          ~s(<hr class="border-base-300/60 my-3" />)

        Regex.match?(~r/^[-–•]\s/, line) ->
          item = String.replace(line, ~r/^[-–•]\s*/, "")
          item = render_inline_markdown(item)
          ~s(<div class="flex gap-1.5 text-xs text-base-content/70 leading-relaxed"><span class="text-base-content/30 shrink-0">•</span><span>#{item}</span></div>)

        String.trim(line) == "" ->
          ~s(<div class="h-2"></div>)

        true ->
          line = render_inline_markdown(line)
          ~s(<p class="text-xs text-base-content/70 leading-relaxed">#{line}</p>)
      end
    end)
    |> Enum.join("\n")
    |> Phoenix.HTML.raw()
  end

  defp render_inline_markdown(text) do
    text
    |> String.replace(~r/\*\*(.+?)\*\*/, "<strong class=\"text-base-content font-medium\">\\1</strong>")
  end

  def new_custom_section(title \\ "New Section", content \\ "") do
    %{
      "id" => generate_id(),
      "type" => "custom",
      "title" => title,
      "content" => content,
      "enabled" => true,
      "locked" => false
    }
  end

  def reorder(%{"sections" => sections} = config, id_order) when is_list(id_order) do
    by_id = Map.new(sections, fn s -> {s["id"], s} end)

    reordered =
      id_order
      |> Enum.map(fn id -> Map.get(by_id, id) end)
      |> Enum.reject(&is_nil/1)

    # Append any sections not in the order list (safety net)
    remaining = Enum.reject(sections, fn s -> s["id"] in id_order end)

    %{config | "sections" => reordered ++ remaining}
  end

  def toggle_section(%{"sections" => sections} = config, section_id) do
    updated =
      Enum.map(sections, fn s ->
        if s["id"] == section_id do
          Map.put(s, "enabled", !s["enabled"])
        else
          s
        end
      end)

    %{config | "sections" => updated}
  end

  def update_section_content(%{"sections" => sections} = config, section_id, content) do
    updated =
      Enum.map(sections, fn s ->
        if s["id"] == section_id and s["locked"] == false do
          Map.put(s, "content", content)
        else
          s
        end
      end)

    %{config | "sections" => updated}
  end

  def update_section_title(%{"sections" => sections} = config, section_id, title) do
    updated =
      Enum.map(sections, fn s ->
        if s["id"] == section_id and s["locked"] == false do
          Map.put(s, "title", title)
        else
          s
        end
      end)

    %{config | "sections" => updated}
  end

  def remove_section(%{"sections" => sections} = config, section_id) do
    updated = Enum.reject(sections, fn s -> s["id"] == section_id and s["locked"] == false end)
    %{config | "sections" => updated}
  end

  # Private

  defp render_section(%{"type" => "custom", "content" => content, "title" => title}, _tenant) do
    if blank?(content), do: nil, else: "### #{title}\n#{content}"
  end

  defp render_section(%{"type" => type, "title" => title}, tenant) do
    case Map.get(@tenant_section_types, type) do
      %{field: field} ->
        value = tenant && Map.get(tenant, field)
        if blank?(value), do: nil, else: "### #{title}\n#{value}"

      nil ->
        nil
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false

  defp generate_id do
    "sec_" <> Base.encode32(:crypto.strong_rand_bytes(5), case: :lower, padding: false)
  end
end
