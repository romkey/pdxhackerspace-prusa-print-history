require 'test_helper'

class IconTest < ActiveSupport::TestCase
  test 'favicon svg uses the bootstrap printer icon' do
    svg = Rails.public_path.join('icon.svg').read

    assert_includes svg, 'aria-label="Prusa Print History"'
    assert_includes svg, '<path d="M5 1a2 2 0 0 0-2 2v2H2'
  end
end
