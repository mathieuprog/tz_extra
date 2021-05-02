if Code.ensure_loaded?(Ecto.Changeset) do
  defmodule TzExtra.Changeset do
    require TzExtra.Compiler

    def validate_time_zone_identifier(%Ecto.Changeset{} = changeset, field, opts \\ []) when is_atom(field) do
      opts =
        opts
        |> Keyword.put(:include_alias, Keyword.get(opts, :allow_alias, false))

      Ecto.Changeset.validate_change changeset, field, {:time_zone_identifier, []}, fn _field, value ->
        if Enum.member?(TzExtra.time_zone_identifiers(opts), value),
          do: [],
          else: [{field, {message(opts, "is not a valid time zone"), [validation: :time_zone_identifier]}}]
      end
    end

    def validate_civil_time_zone_identifier(%Ecto.Changeset{} = changeset, field, opts \\ []) when is_atom(field) do
      opts =
        opts
        |> Keyword.put(:include_alias, Keyword.get(opts, :allow_alias, false))
        |> Keyword.put(:prepend_utc, Keyword.get(opts, :allow_utc, false))

      Ecto.Changeset.validate_change changeset, field, {:civil_time_zone_identifier, []}, fn _field, value ->
        if Enum.member?(TzExtra.civil_time_zone_identifiers(opts), value),
          do: [],
          else: [{field, {message(opts, "is not a valid time zone"), [validation: :civil_time_zone_identifier]}}]
      end
    end

    def validate_iso_country_code(%Ecto.Changeset{} = changeset, field, opts \\ []) when is_atom(field) do
      Ecto.Changeset.validate_change changeset, field, {:country_code, []}, fn _field, value ->
        if Enum.any?(TzExtra.countries(), fn %{code: country_code} -> country_code == value end),
          do: [],
          else: [{field, {message(opts, "is not a valid country code"), [validation: :country_code]}}]
      end
    end

    defp message(opts, key \\ :message, default) do
      Keyword.get(opts, key, default)
    end
  end
end
