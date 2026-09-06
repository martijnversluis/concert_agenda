module ConcertSyncing
  extend ActiveSupport::Concern

  private

  def ensure_concert_sync!
    return unless signed_in?
    return if current_user.concerts_syncing?
    return unless current_user.concerts_stale?

    current_user.update!(concerts_syncing_since: Time.current)
    FetchConcertsForUserJob.perform_later(current_user.id)
  end

  def syncing?
    signed_in? && current_user.concerts_syncing?
  end
end
