defmodule Swati.Cases.Linking do
  alias Swati.Cases.Queries
  alias Swati.Policies

  @default_policy %{
    "window_hours" => 48,
    "min_confidence" => 0.6,
    "require_category" => false
  }

  @spec pick_case(binary(), binary(), String.t() | nil, list(map() | nil)) ::
          {:reuse, Swati.Cases.Case.t(), map()} | nil
  def pick_case(tenant_id, customer_id, category, policies) do
    policy = policy_from(policies)
    window_hours = normalize_integer(Map.get(policy, "window_hours")) || 48
    min_confidence = normalize_float(Map.get(policy, "min_confidence")) || 0.6
    require_category = Map.get(policy, "require_category") == true

    window_seconds = window_hours * 3600

    candidates = Queries.list_open_cases_for_customer(tenant_id, customer_id)

    candidates
    |> Enum.map(&score_case(&1, category, window_seconds, require_category))
    |> Enum.max_by(fn {_case, score, _info} -> score end, fn -> nil end)
    |> case do
      {case_record, score, info} when score >= min_confidence ->
        {:reuse, case_record, Map.put(info, "confidence", score)}

      _ ->
        nil
    end
  end

  def policy_from(policies) when is_list(policies) do
    policies
    |> Enum.map(&linking_policy/1)
    |> then(fn overrides -> Policies.merge([@default_policy | overrides]) end)
  end

  defp score_case(case_record, category, window_seconds, require_category) do
    now = DateTime.utc_now()
    last_activity_at = case_record.updated_at || case_record.opened_at || now
    age_seconds = abs(DateTime.diff(now, last_activity_at, :second))
    within_window = age_seconds <= window_seconds

    matched_category =
      case {category, case_record.category} do
        {nil, _} -> false
        {"", _} -> false
        {cat, cat} -> true
        _ -> false
      end

    score =
      0.2 +
        if(within_window, do: 0.5, else: 0.0) +
        if(matched_category, do: 0.3, else: 0.0)

    score = if(require_category and not matched_category, do: 0.0, else: score)

    info = %{
      "strategy" => "open_case",
      "window_hours" => div(window_seconds, 3600),
      "within_window" => within_window,
      "matched_category" => matched_category,
      "last_activity_at" => DateTime.to_iso8601(last_activity_at)
    }

    {case_record, min(score, 1.0), info}
  end

  defp linking_policy(policy) when is_map(policy) do
    policy
    |> Policies.normalize()
    |> Map.get("case_linking", %{})
    |> stringify_keys()
  end

  defp linking_policy(_policy), do: %{}

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_keys(_), do: %{}

  defp normalize_integer(nil), do: nil
  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _rest} -> parsed
      :error -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp normalize_float(nil), do: nil
  defp normalize_float(value) when is_float(value), do: value

  defp normalize_float(value) when is_integer(value), do: value / 1

  defp normalize_float(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _rest} -> parsed
      :error -> nil
    end
  end

  defp normalize_float(_value), do: nil
end
