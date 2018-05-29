class User < ApplicationRecord
  has_many :work_sessions

  def active_worksession
    self.work_sessions.find_by_end_date(nil)
  end
end
