module SpotifyThrottle
  MIN_INTERVAL = 0.6
  MAX_RETRIES  = 2
  MAX_INLINE_WAIT = 2.0  # never block a web request longer than this

  class CoolingDown < StandardError
    attr_reader :retry_after
    def initialize(retry_after)
      @retry_after = retry_after
      super("Spotify is rate-limited (retry in #{retry_after.round}s)")
    end
  end

  @mutex = Mutex.new
  @last_call = 0.0
  @cool_until = 0.0

  class << self
    def cool_remaining
      @mutex.synchronize { [@cool_until - Time.now.to_f, 0].max }
    end

    def cooling_down?
      cool_remaining > 0
    end

    def call
      MAX_RETRIES.times do |attempt|
        wait_room!
        begin
          return yield
        rescue RestClient::TooManyRequests => e
          delay = retry_after(e) || (2**attempt) * 5
          Rails.logger.warn("Spotify 429; cooling down for #{delay}s")
          @mutex.synchronize { @cool_until = Time.now.to_f + delay }
          raise CoolingDown.new(delay) if attempt == MAX_RETRIES - 1
        end
      end
    end

    private

    def wait_room!
      cool_gap, pace_gap = @mutex.synchronize do
        now = Time.now.to_f
        [@cool_until - now, MIN_INTERVAL - (now - @last_call)]
      end

      raise CoolingDown.new(cool_gap) if cool_gap > MAX_INLINE_WAIT

      total = [cool_gap, pace_gap, 0].max
      sleep(total) if total > 0
      @mutex.synchronize { @last_call = Time.now.to_f }
    end

    def retry_after(exception)
      hdr = exception.response&.headers&.dig(:retry_after)
      hdr.to_i if hdr
    end
  end
end
