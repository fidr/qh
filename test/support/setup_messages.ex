defmodule QTest.Repo.Migrations.SetupMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :message, :text
      add :likes, :integer
      timestamps()
    end
  end
end
