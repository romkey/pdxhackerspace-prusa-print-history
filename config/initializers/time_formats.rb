Time::DATE_FORMATS[:short] = ->(time) { time.strftime('%b %-d, %H:%M') }
Time::DATE_FORMATS[:precise] = ->(time) { time.strftime('%Y-%m-%d %H:%M:%S %Z') }
Date::DATE_FORMATS[:short] = ->(date) { date.strftime('%b %-d') }
