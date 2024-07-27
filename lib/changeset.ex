if Code.ensure_loaded?(Ecto.Changeset) do
  defmodule TzExtra.Changeset do
    require TzExtra.Compiler

    def validate_time_zone_id(%Ecto.Changeset{} = changeset, field, opts \\ [])
        when is_atom(field) do
      opts =
        opts
        |> Keyword.put(:include_aliases, Keyword.get(opts, :allow_alias, false))

      Ecto.Changeset.validate_change(changeset, field, :time_zone_id, fn _field, value ->
        if Enum.member?(TzExtra.time_zone_ids(opts), value),
          do: [],
          else: [
            {field, {message(opts, "is not a valid time zone"), [validation: :time_zone_id]}}
          ]
      end)
    end

    def validate_civil_time_zone_id(%Ecto.Changeset{} = changeset, field, opts \\ [])
        when is_atom(field) do
      opts =
        opts
        |> Keyword.put(:include_aliases, Keyword.get(opts, :allow_alias, false))

      Ecto.Changeset.validate_change(changeset, field, :civil_time_zone_id, fn _field, value ->
        if Enum.member?(TzExtra.civil_time_zone_ids(opts), value),
          do: [],
          else: [
            {field,
             {message(opts, "is not a valid time zone"), [validation: :civil_time_zone_id]}}
          ]
      end)
    end

    def validate_iso_country_code(%Ecto.Changeset{} = changeset, field, opts \\ [])
        when is_atom(field) do
      Ecto.Changeset.validate_change(changeset, field, :iso_country_code, fn _field, value ->
        if Enum.any?(TzExtra.countries(), fn %{code: country_code} -> country_code == value end),
          do: [],
          else: [
            {field,
             {message(opts, "is not a valid country code"), [validation: :iso_country_code]}}
          ]
      end)
    end

    defp message(opts, key \\ :message, default) do
      Keyword.get(opts, key, default)
    end
  end
end
