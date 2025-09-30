class Task < ApplicationRecord
  # Validations
  validates :title, presence: true
  validates :description, presence: true
  validates :status, presence: true
  validates :due_date, presence: true
  validates :priority, presence: true

  # Scopes for filtering
  scope :with_status, ->(value) { value.present? ? where(status: value) : all }
  scope :with_priority, ->(value) { value.present? ? where(priority: value) : all }
  scope :due_before, ->(value) { value.present? ? where('due_date <= ?', value) : all }
  scope :due_after, ->(value) { value.present? ? where('due_date >= ?', value) : all }
  scope :query, ->(q) {
    if q.present?
      where('title ILIKE :q OR description ILIKE :q', q: "%#{q}%")
    else
      all
    end
  }

  # Broadcast changes to Turbo Stream
  after_create_commit do
    broadcast_append_to "tasks", target: "tasks_list"
  end

  after_update_commit do
    broadcast_replace_to "tasks"
  end

  after_destroy_commit do
    broadcast_remove_to "tasks"
  end
end
