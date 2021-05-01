if Code.ensure_loaded?(Ecto.Changeset) do
  defmodule TzExtra.Changeset do
    require TzExtra.Compiler

    def validate_time_zone(%Ecto.Changeset{} = changeset, field, opts \\ []) when is_atom(field) do
      Ecto.Changeset.validate_change changeset, field, {:time_zone, []}, fn _field, value ->
        if Enum.member?(TzExtra.time_zone_identifiers(opts), value),
          do: [],
          else: [{field, {message(opts, "is not a valid time zone identifier"), [validation: :time_zone]}}]
      end
    end

    def validate_iso_country_code(%Ecto.Changeset{} = changeset, field, opts \\ []) when is_atom(field) do
      Ecto.Changeset.validate_change changeset, field, {:country_code, []}, fn _field, value ->
        if Enum.any?(TzExtra.countries(), fn %{code: country_code} -> country_code == value end),
          do: [],
          else: [{field, {message(opts, "is not a valid ISO country code"), [validation: :country_code]}}]
      end
    end

    defp message(opts, key \\ :message, default) do
      Keyword.get(opts, key, default)
    end
  end
end
