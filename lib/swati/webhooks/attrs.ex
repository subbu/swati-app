defmodule Swati.Webhooks.Attrs do
  @method_values [:get, :post, :put, :patch, :delete]
  @auth_values [:bearer, :none]
  @status_values [:active, :disabled]
  @input_types ["string", "number", "integer", "boolean", "object", "array"]

  def normalize(attrs) do
    attrs = Map.new(attrs, fn {key, value} -> {to_string(key), value} end)

    with {:ok, header_entries, headers} <- normalize_headers(attrs),
         {:ok, inputs} <- normalize_inputs(attrs),
         {:ok, payload} <- parse_payload(Map.get(attrs, "sample_payload")) do
      attrs =
        attrs
        |> Map.put("header_entries", header_entries)
        |> Map.put("headers", headers)
        |> Map.put("inputs", inputs)

      attrs =
        if inputs != [] do
          attrs
          |> Map.put("input_schema", schema_from_inputs(inputs))
          |> Map.put("sample_payload", payload_from_inputs(inputs))
        else
          attrs
          |> Map.put("sample_payload", payload)
          |> normalize_input_schema(payload)
        end

      normalized =
        attrs
        |> normalize_tool_name()
        |> normalize_method()
        |> normalize_auth_type()
        |> normalize_status()

      {:ok, normalized}
    end
  end

  defp normalize_input_schema(attrs, nil), do: Map.put_new(attrs, "input_schema", %{})

  defp normalize_input_schema(attrs, payload) when is_map(payload) do
    Map.put(attrs, "input_schema", schema_from_payload(payload))
  end

  defp normalize_input_schema(attrs, _payload), do: Map.put_new(attrs, "input_schema", %{})

  defp normalize_tool_name(attrs) do
    tool_name = Map.get(attrs, "tool_name")
    name = Map.get(attrs, "name")

    source =
      cond do
        present?(tool_name) -> tool_name
        present?(name) -> name
        true -> nil
      end

    if is_nil(source) do
      attrs
    else
      normalized =
        source
        |> to_string()
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9_-]+/, "-")
        |> String.trim("-")

      if normalized == "" do
        Map.put(attrs, "tool_name", "webhook")
      else
        Map.put(attrs, "tool_name", normalized)
      end
    end
  end

  defp normalize_method(attrs) do
    method = to_enum(Map.get(attrs, "http_method"), @method_values, :post)
    Map.put(attrs, "http_method", method)
  end

  defp normalize_auth_type(attrs) do
    auth = to_enum(Map.get(attrs, "auth_type"), @auth_values, :none)
    Map.put(attrs, "auth_type", auth)
  end

  defp normalize_status(attrs) do
    status = to_enum(Map.get(attrs, "status"), @status_values, :active)
    Map.put(attrs, "status", status)
  end

  defp normalize_headers(attrs) do
    header_entries =
      attrs
      |> Map.get("header_entries")
      |> normalize_list()
      |> Enum.map(&normalize_header_entry/1)
      |> Enum.reject(&is_nil/1)

    if header_entries != [] do
      headers =
        Enum.reduce(header_entries, %{}, fn entry, acc ->
          Map.put(acc, entry["key"], entry["value"])
        end)

      {:ok, header_entries, headers}
    else
      case parse_headers(Map.get(attrs, "headers")) do
        {:ok, headers} ->
          {:ok, headers_to_entries(headers), headers}

        {:error, _reason} = error ->
          error
      end
    end
  end

  defp normalize_inputs(attrs) do
    inputs =
      attrs
      |> Map.get("inputs")
      |> normalize_list()
      |> Enum.map(&normalize_input/1)
      |> Enum.reject(&is_nil/1)

    {:ok, inputs}
  end

  defp normalize_header_entry(entry) when is_map(entry) do
    key = entry_value(entry, "key") |> to_string() |> String.trim()
    value = entry_value(entry, "value") |> to_string() |> String.trim()

    if key == "" do
      nil
    else
      %{"key" => key, "value" => value}
    end
  end

  defp normalize_header_entry(_entry), do: nil

  defp normalize_input(entry) when is_map(entry) do
    name = entry_value(entry, "name") |> to_string() |> String.trim()

    if name == "" do
      nil
    else
      type = normalize_input_type(entry_value(entry, "type"))
      required = truthy?(entry_value(entry, "required"))
      description = entry_value(entry, "description") |> to_string() |> String.trim()
      example = entry_value(entry, "example") |> to_string() |> String.trim()

      %{
        "name" => name,
        "type" => type,
        "required" => required,
        "description" => description,
        "example" => example
      }
    end
  end

  defp normalize_input(_entry), do: nil

  defp normalize_input_type(nil), do: "string"
  defp normalize_input_type(""), do: "string"

  defp normalize_input_type(value) when is_atom(value) do
    normalize_input_type(Atom.to_string(value))
  end

  defp normalize_input_type(value) when is_binary(value) do
    value = String.downcase(value)
    if value in @input_types, do: value, else: "string"
  end

  defp normalize_input_type(_value), do: "string"

  defp normalize_list(nil), do: []
  defp normalize_list(list) when is_list(list), do: list

  defp normalize_list(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {list_index(key), value} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  defp normalize_list(_value), do: []

  defp list_index(key) when is_integer(key), do: key

  defp list_index(key) when is_binary(key) do
    case Integer.parse(key) do
      {value, _} -> value
      :error -> 0
    end
  end

  defp list_index(_key), do: 0

  defp payload_from_inputs(inputs) do
    payload =
      Enum.reduce(inputs, %{}, fn input, acc ->
        name = Map.get(input, "name")
        example = Map.get(input, "example")

        if present?(example) do
          Map.put(acc, name, parse_example(example))
        else
          acc
        end
      end)

    if payload == %{}, do: nil, else: payload
  end

  defp schema_from_inputs(inputs) do
    properties =
      inputs
      |> Enum.map(fn input ->
        name = Map.get(input, "name")
        type = Map.get(input, "type") || "string"
        description = Map.get(input, "description")

        schema =
          %{"type" => type}
          |> maybe_put_description(description)

        {name, schema}
      end)
      |> Enum.reject(fn {name, _} -> is_nil(name) or name == "" end)
      |> Map.new()

    required =
      inputs
      |> Enum.filter(&Map.get(&1, "required"))
      |> Enum.map(&Map.get(&1, "name"))
      |> Enum.reject(&is_nil/1)

    %{
      "type" => "object",
      "properties" => properties,
      "required" => required
    }
  end

  defp maybe_put_description(schema, description) do
    if present?(description) do
      Map.put(schema, "description", description)
    else
      schema
    end
  end

  defp headers_to_entries(headers) when is_map(headers) do
    headers
    |> Enum.map(fn {key, value} -> %{"key" => to_string(key), "value" => to_string(value)} end)
    |> Enum.sort_by(& &1["key"])
  end

  defp headers_to_entries(_headers), do: []

  defp entry_value(entry, key) do
    Map.get(entry, key) || Map.get(entry, safe_existing_atom(key)) || ""
  end

  defp to_enum(nil, _values, fallback), do: fallback
  defp to_enum("", _values, fallback), do: fallback

  defp to_enum(value, values, fallback) when is_atom(value) do
    if value in values, do: value, else: fallback
  end

  defp to_enum(value, values, fallback) when is_binary(value) do
    atom = safe_existing_atom(value)
    if atom in values, do: atom, else: fallback
  end

  defp to_enum(_value, _values, fallback), do: fallback

  defp parse_headers(nil), do: {:ok, %{}}
  defp parse_headers(""), do: {:ok, %{}}
  defp parse_headers(headers) when is_map(headers), do: {:ok, stringify_map(headers)}

  defp parse_headers(headers) when is_binary(headers) do
    headers
    |> String.trim()
    |> case do
      "" ->
        {:ok, %{}}

      value ->
        case Jason.decode(value) do
          {:ok, decoded} when is_map(decoded) ->
            {:ok, stringify_map(decoded)}

          _ ->
            parse_kv_lines(value, :headers)
        end
    end
  end

  defp parse_payload(nil), do: {:ok, nil}
  defp parse_payload(""), do: {:ok, nil}
  defp parse_payload(payload) when is_map(payload), do: {:ok, payload}

  defp parse_payload(payload) when is_binary(payload) do
    payload
    |> String.trim()
    |> case do
      "" ->
        {:ok, nil}

      value ->
        case Jason.decode(value) do
          {:ok, decoded} when is_map(decoded) ->
            {:ok, decoded}

          _ ->
            parse_kv_lines(value, :sample_payload)
        end
    end
  end

  defp parse_kv_lines(value, field) do
    lines =
      value
      |> String.split(["\n", "\r\n"], trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {entries, errors} =
      Enum.reduce(lines, {[], []}, fn line, {items, errs} ->
        case split_kv(line) do
          {:ok, {key, val}} ->
            {[{key, val} | items], errs}

          :error ->
            {items, [line | errs]}
        end
      end)

    if entries == [] or errors != [] do
      {:error, {field, "must be JSON or key: value lines"}}
    else
      {:ok, Map.new(entries)}
    end
  end

  defp split_kv(line) do
    case String.split(line, ":", parts: 2) do
      [key, value] ->
        {:ok, {String.trim(key), parse_scalar(String.trim(value))}}

      _ ->
        case String.split(line, "=", parts: 2) do
          [key, value] -> {:ok, {String.trim(key), parse_scalar(String.trim(value))}}
          _ -> :error
        end
    end
  end

  defp parse_scalar(value) do
    cond do
      value in ["true", "false"] -> value == "true"
      value == "null" -> nil
      String.match?(value, ~r/^-?\d+$/) -> String.to_integer(value)
      String.match?(value, ~r/^-?\d+\.\d+$/) -> String.to_float(value)
      true -> value
    end
  end

  defp parse_example(value) when is_binary(value) do
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

  defp parse_example(value), do: parse_scalar(to_string(value))

  defp stringify_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp schema_from_payload(payload) when is_map(payload) do
    properties =
      payload
      |> Enum.map(fn {key, value} -> {to_string(key), schema_for_value(value)} end)
      |> Map.new()

    %{
      "type" => "object",
      "properties" => properties,
      "required" => Map.keys(properties)
    }
  end

  defp schema_for_value(value) when is_map(value) do
    schema_from_payload(value)
  end

  defp schema_for_value(value) when is_list(value) do
    case value do
      [] -> %{"type" => "array"}
      [first | _] -> %{"type" => "array", "items" => schema_for_value(first)}
    end
  end

  defp schema_for_value(value) when is_boolean(value), do: %{"type" => "boolean"}
  defp schema_for_value(value) when is_integer(value), do: %{"type" => "integer"}
  defp schema_for_value(value) when is_float(value), do: %{"type" => "number"}
  defp schema_for_value(value) when is_binary(value), do: %{"type" => "string"}
  defp schema_for_value(nil), do: %{"type" => "string"}
  defp schema_for_value(_value), do: %{"type" => "string"}

  defp truthy?(value) when value in [true, "true", "on", "1"], do: true
  defp truthy?(_value), do: false

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(nil), do: false
  defp present?(_value), do: true

  defp safe_existing_atom(value) when is_binary(value) do
    try do
      String.to_existing_atom(value)
    rescue
      ArgumentError -> :__invalid__
    end
  end

  defp safe_existing_atom(_value), do: :__invalid__
end
