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

    def validate_country_time_zone(%Ecto.Changeset{} = changeset, fields_meta, opts \\ []) do
      field_names = Keyword.keys(fields_meta)
      field_types = Keyword.values(fields_meta)

      unless [:country_code, :time_zone_id] -- field_types == [] do
        raise "second argument must be a keyword list where the values are :country_code and :time_zone_id"
      end

      ChangesetHelpers.validate_changes(changeset, field_names, :country_time_zone, fn fields ->
        [{field_name_1, field_value_1}, {_field_name_2, field_value_2}] = fields

        {country_code, time_zone_id} =
          cond do
            Keyword.fetch!(fields_meta, field_name_1) == :country_code ->
              {field_value_1, field_value_2}

            true ->
              {field_value_2, field_value_1}
          end

        case TzExtra.country_time_zone(country_code, time_zone_id) do
          {:ok, _} ->
            []

          {:error, _} ->
            [
              {field_name_1,
               {message(opts, "is not a valid country time zone"),
                [validation: :country_time_zone]}}
            ]
        end
      end)
    end

    defp message(opts, key \\ :message, default) do
      Keyword.get(opts, key, default)
    end
  end
end
