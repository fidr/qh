defmodule QTest.Repo.Migrations.SetupTables do
  use Ecto.Migration

  def change do
    create table("users") do
      add(:name, :text)
      add(:age, :integer)
      add(:nicknames, {:array, :text})
      timestamps()
    end
  end
end
