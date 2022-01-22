defmodule QTest.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:name, :string)
    field(:age, :integer)
    field(:nicknames, {:array, :string})
    has_many :messages, QTest.Message
    timestamps()
  end

  def changeset(user \\ %__MODULE__{}, params) do
    user
    |> cast(params, __schema__(:fields))
    |> validate_required([:name])
  end
end
