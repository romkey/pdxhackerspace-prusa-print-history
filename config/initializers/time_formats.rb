Time::DATE_FORMATS[:short] = ->(time) { time.strftime('%b %-d, %H:%M') }
Date::DATE_FORMATS[:short] = ->(date) { date.strftime('%b %-d') }
