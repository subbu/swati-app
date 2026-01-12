defmodule SwatiWeb.WebhooksLive.FormHelpers do
  @input_type_values ["string", "number", "integer", "boolean", "object", "array"]

  def input_type_options do
    [
      {"String", "string"},
      {"Number", "number"},
      {"Integer", "integer"},
      {"Boolean", "boolean"},
      {"Object (JSON)", "object"},
      {"Array (JSON)", "array"}
    ]
  end

  def normalize_input_type(nil), do: "string"
  def normalize_input_type(""), do: "string"

  def normalize_input_type(value) when is_atom(value) do
    normalize_input_type(Atom.to_string(value))
  end

  def normalize_input_type(value) when is_binary(value) do
    value = String.downcase(value)
    if value in @input_type_values, do: value, else: "string"
  end

  def normalize_input_type(_value), do: "string"

  def payload_preview(inputs) do
    payload =
      Enum.reduce(inputs, %{}, fn input, acc ->
        name = Map.get(input, "name") |> to_string() |> String.trim()
        example = Map.get(input, "example") |> to_string() |> String.trim()

        if name != "" and example != "" do
          Map.put(acc, name, parse_example(example))
        else
          acc
        end
      end)

    if payload == %{}, do: "", else: Jason.encode!(payload, pretty: true)
  end

  def parse_example(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      String.starts_with?(trimmed, "{") or String.starts_with?(trimmed, "[") ->
        case Jason.decode(trimmed) do
          {:ok, decoded} -> decoded
          _ -> parse_scalar(trimmed)
        end

      true ->
        parse_scalar(trimmed)
    end
  end

  def parse_example(value), do: parse_scalar(to_string(value))

  def parse_scalar(value) do
    cond do
      value in ["true", "false"] -> value == "true"
      value == "null" -> nil
      String.match?(value, ~r/^-?\d+$/) -> String.to_integer(value)
      String.match?(value, ~r/^-?\d+\.\d+$/) -> String.to_float(value)
      true -> value
    end
  end

  def example_for(payload, name) when is_map(payload) do
    payload
    |> Map.get(name)
    |> format_example()
  end

  def example_for(_payload, _name), do: ""

  def format_example(nil), do: ""
  def format_example(value) when is_binary(value), do: value

  def format_example(value) when is_list(value) or is_map(value) do
    Jason.encode!(value)
  end

  def format_example(value), do: to_string(value)

  def schema_properties(schema) when is_map(schema) do
    schema
    |> Map.get("properties", %{})
    |> Enum.sort_by(&elem(&1, 0))
  end

  def schema_properties(_schema), do: []

  def schema_required(schema) when is_map(schema) do
    schema
    |> Map.get("required", [])
    |> Enum.map(&to_string/1)
  end

  def schema_required(_schema), do: []

  def empty_input do
    %{
      "name" => "",
      "type" => "string",
      "required" => false,
      "description" => "",
      "example" => ""
    }
  end

  def empty_header do
    %{"key" => "", "value" => ""}
  end

  def normalize_list(nil), do: []
  def normalize_list(list) when is_list(list), do: list

  def normalize_list(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {list_index(key), value} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  def normalize_list(_value), do: []

  def remove_at(list, index) when is_binary(index) do
    case Integer.parse(index) do
      {value, _} -> remove_at(list, value)
      :error -> list
    end
  end

  def remove_at(list, index) when is_integer(index) do
    List.delete_at(list, index)
  end

  def remove_at(list, _index), do: list

  def entry_value(entry, key) do
    Map.get(entry, key) || Map.get(entry, safe_existing_atom(key)) || ""
  end

  def truthy?(value) when value in [true, "true", "on", "1"], do: true
  def truthy?(_value), do: false

  def present?(value) when is_binary(value), do: String.trim(value) != ""
  def present?(nil), do: false
  def present?(_value), do: true

  defp list_index(key) when is_integer(key), do: key

  defp list_index(key) when is_binary(key) do
    case Integer.parse(key) do
      {value, _} -> value
      :error -> 0
    end
  end

  defp list_index(_key), do: 0

  defp safe_existing_atom(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> :__invalid__
    end
  end

  defp safe_existing_atom(_key), do: :__invalid__
end
