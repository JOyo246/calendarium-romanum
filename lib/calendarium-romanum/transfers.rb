module CalendariumRomanum

  # Internal {Calendar} component.
  # Resolves transfers of conflicting solemnities.
  #
  # For any day {Temporale} has a {Celebration}.
  # Often {Sanctorale} has one (or more), too.
  # {Calendar} handles these conflicts, in most cases
  # by throwing away all the proposed {Celebration}s except
  # of the one of highest rank.
  # But when there are two conflicting _solemnities_,
  # one is celebrated on the given day and the less lucky one
  # must be transferred to another day.
  # However, not all days are valid as targets of solemnity transfer.
  #
  # @api private
  class Transfers
    # @param temporale [Temporale]
    # @param sanctorale [Sanctorale]
    def initialize(temporale, sanctorale)
      @temporale = temporale
      @sanctorale = sanctorale
    end

    def self.call(temporale, sanctorale)
      new(temporale, sanctorale).call
    end

    def call
      @transferred = {}

      dates = @sanctorale.solemnities.keys.collect do |abstract_date|
        concretize_abstract_date abstract_date
      end.sort

      dates.each do |date|
        tc = @temporale[date]
        next unless tc.solemnity?

        sc = @sanctorale[date]
        next unless sc.size == 1 && sc.first.solemnity?

        loser = [tc, sc.first].sort_by(&:rank).first

        transfer_to =
          if loser.symbol == :annunciation && in_holy_week?(date)
            monday_easter2 = @temporale.easter_sunday + 8
            valid_destination?(monday_easter2) ? monday_easter2 : free_day_closest_to(monday_easter2)
          else
            free_day_closest_to(date)
          end
        @transferred[transfer_to] = loser
      end

      @transferred
    end

    private

    def valid_destination?(date)
      return false if @transferred.has_key? date
      return false if @temporale[date].rank >= Ranks::FEAST_PROPER

      sc = @sanctorale[date]
      return false if sc.size > 0 && sc.first.rank >= Ranks::FEAST_PROPER

      true
    end

    # Converts an AbstractDate to a Date in the given
    # liturgical year.
    # It isn't guaranteed to work well (and probably doesn't work well)
    # for the grey zone of dates between earliest and latest
    # possible date of the first Advent Sunday, but that's no problem
    # as long as there are no sanctorale solemnities in this
    # date range.
    def concretize_abstract_date(abstract_date)
      d = abstract_date.concretize(@temporale.year + 1)
      if @temporale.date_range.include? d
        d
      else
        abstract_date.concretize(@temporale.year)
      end
    end

    def free_day_closest_to(date)
      dates_around(date).find {|d| valid_destination?(d) }
    end

    def dates_around(date)
      return to_enum(__method__, date) unless block_given?

      1.upto(100) do |i|
        yield date + i
        yield date - i
      end

      raise 'this point should never be reached'
    end

    def in_holy_week?(date)
      holy_week = (@temporale.palm_sunday .. @temporale.easter_sunday)

      holy_week.include? date
    end
  end
end
