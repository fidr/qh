defmodule QTest.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    belongs_to(:user, QTest.User)
    field(:message, :string)
    field(:likes, :integer, default: 0)
    timestamps()
  end

  def changeset(user \\ %__MODULE__{}, params) do
    user
    |> cast(params, __schema__(:fields))
    |> foreign_key_constraint(:user_id)
    |> validate_required([:message])
  end
end
