defimpl FunWithFlags.Actor, for: Swati.Tenancy.Tenant do
  def id(%Swati.Tenancy.Tenant{id: id}) when not is_nil(id), do: "tenant:#{id}"

  def id(_tenant),
    do: raise(ArgumentError, "tenant must have an id for feature flag actor checks")
end
