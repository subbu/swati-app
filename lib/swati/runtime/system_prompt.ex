defmodule Swati.Runtime.SystemPrompt do
  alias Swati.Cases.Memory

  @spec build(map()) :: String.t()
  def build(opts) when is_map(opts) do
    agent_name = Map.get(opts, :agent_name) || "Swati"
    instructions = Map.get(opts, :agent_instructions) || ""
    customer = Map.get(opts, :customer)
    identity = Map.get(opts, :identity)
    case_record = Map.get(opts, :case_record)
    session = Map.get(opts, :session)
    endpoint = Map.get(opts, :endpoint)
    channel = Map.get(opts, :channel)
    prompt_overrides = Map.get(opts, :prompt_overrides) || %{prepend: [], append: []}

    memory =
      case case_record do
        %{memory: memory} -> Memory.normalize(memory)
        _ -> Memory.normalize(nil)
      end

    sections =
      [
        "# Swati Voice Agent System Prompt",
        render_blocks(Map.get(prompt_overrides, :prepend, [])),
        role_section(agent_name, instructions),
        style_section(),
        context_section(channel, endpoint, session, customer),
        customer_section(customer, identity),
        case_section(case_record, memory),
        session_section(session, endpoint),
        render_blocks(Map.get(prompt_overrides, :append, []))
      ]
      |> List.flatten()
      |> Enum.reject(&blank?/1)

    sections
    |> Enum.join("\n\n")
    |> String.trim()
  end

  defp role_section(agent_name, instructions) do
    instructions = String.trim(instructions)

    base = [
      "## Role",
      "You are #{agent_name}, a live phone agent handling real-time calls.",
      "Use the context below to help the caller. Do not read internal notes or IDs aloud."
    ]

    base =
      if instructions == "" do
        base
      else
        base ++ ["", "### Base Instructions", instructions]
      end

    Enum.join(base, "\n")
  end

  defp style_section do
    [
      "## Voice and Style",
      "- Speak naturally, warm and human. Use contractions when it sounds natural.",
      "- Keep sentences short. Ask one question at a time.",
      "- Confirm critical details like names, numbers, dates, and amounts.",
      "- Acknowledge emotions and intent before moving to actions.",
      "- Avoid robotic phrasing, tool names, or system/policy references."
    ]
    |> Enum.join("\n")
  end

  defp context_section(channel, endpoint, session, customer) do
    bullets =
      [
        bullet("Channel", channel_label(channel)),
        bullet("Direction", session && session.direction),
        bullet("Endpoint", endpoint_label(endpoint)),
        bullet("Customer language", customer && customer.language),
        bullet("Customer timezone", customer && customer.timezone)
      ]
      |> Enum.filter(& &1)

    ["## Call Context", bullets]
    |> List.flatten()
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n")
  end

  defp customer_section(customer, identity) do
    bullets =
      [
        bullet("Name", customer && customer.name),
        bullet("Primary phone", customer && customer.primary_phone),
        bullet("Primary email", customer && customer.primary_email),
        bullet("Identity", identity_label(identity))
      ]
      |> Enum.filter(& &1)

    ["## Customer", bullets]
    |> List.flatten()
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n")
  end

  defp case_section(nil, _memory) do
    "## Case\n- No case context available."
  end

  defp case_section(case_record, memory) do
    commitments = list_items(Map.get(memory, "commitments"))
    constraints = list_items(Map.get(memory, "constraints"))
    next_actions = list_items(Map.get(memory, "next_actions"))
    memory_summary = presence(Map.get(memory, "summary")) || "None yet"

    bullets =
      [
        bullet("Status", case_record.status),
        bullet("Priority", case_record.priority),
        bullet("Category", case_record.category),
        bullet("Title", case_record.title),
        bullet("Case summary", case_record.summary),
        bullet("Memory summary", memory_summary)
      ]
      |> Enum.filter(& &1)

    memory_bullets =
      [
        nested_list("Commitments", commitments),
        nested_list("Constraints", constraints),
        nested_list("Next actions", next_actions)
      ]
      |> List.flatten()
      |> Enum.reject(&blank?/1)

    ["## Case", bullets, memory_bullets]
    |> List.flatten()
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n")
  end

  defp session_section(nil, _endpoint) do
    "## Session\n- No session context available."
  end

  defp session_section(session, endpoint) do
    bullets =
      [
        bullet("Session external ID", session.external_id),
        bullet("Session direction", session.direction),
        bullet("Endpoint address", endpoint && endpoint.address)
      ]
      |> Enum.filter(& &1)

    ["## Session", bullets]
    |> List.flatten()
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n")
  end

  defp render_blocks(blocks) when is_list(blocks) do
    blocks
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&blank?/1)
  end

  defp channel_label(nil), do: nil

  defp channel_label(channel) do
    name = channel.name || channel.key
    type = channel.type

    cond do
      is_binary(name) and is_binary(type) -> "#{name} (#{type})"
      is_binary(name) -> name
      is_binary(type) -> type
      true -> nil
    end
  end

  defp endpoint_label(nil), do: nil

  defp endpoint_label(endpoint) do
    endpoint.display_name || endpoint.address
  end

  defp identity_label(nil), do: nil

  defp identity_label(identity) do
    kind = identity.kind
    address = identity.address
    external_id = identity.external_id

    parts =
      [
        kind && to_string(kind),
        address,
        external_id && "external_id: #{external_id}"
      ]
      |> Enum.filter(& &1)

    case parts do
      [] -> nil
      _ -> Enum.join(parts, " | ")
    end
  end

  defp bullet(_label, nil), do: nil
  defp bullet(_label, ""), do: nil

  defp bullet(label, value) when is_atom(value) do
    bullet(label, Atom.to_string(value))
  end

  defp bullet(label, value) do
    "- #{label}: #{value}"
  end

  defp nested_list(label, []), do: ["- #{label}: None yet"]

  defp nested_list(label, items) do
    ["- #{label}:" | Enum.map(items, &"  - #{&1}")]
  end

  defp list_items(items) when is_list(items) do
    items
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp list_items(_items), do: []

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(value), do: String.trim(to_string(value)) == ""

  defp presence(value) do
    if blank?(value), do: nil, else: value
  end
end
