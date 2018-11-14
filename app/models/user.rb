class User < ApplicationRecord
  validates :username, presence: true

  def destroy_scheduled_jobs(job_name)
    user = self
    ids = [user.id, user.uid]
    ss = Sidekiq::ScheduledSet.new
    ss.select do |s|
      job = s.item['wrapped']
      arg = s.item['args'][0]
      if arg.class == Hash
        condition = arg['arguments'].all? { |i| ids.include? i }
      else
        condition = arg == user.id || user.uid
      end
      condition && job == job_name
    end.each(&:delete)
    job = Object.const_get job_name
  end

  def is_emf?
    self.company_id == 0
  end
end
