require 'test_helper'

class JobsToolsPartialTest < ActionView::TestCase
  test 'renders nozzle and material for each tool' do
    job = jobs(:active_xl)

    render partial: 'jobs/tools', locals: { tools: job.tools, section_label: 'Print heads used' }

    assert_select '.h-section-label', text: 'Print heads used'
    assert_select 'td', text: 'PLA'
    assert_select 'td', text: 'PETG'
    assert_select 'td', text: '0.4 mm'
    assert_select 'td', text: '0.6 mm'
  end

  test 'renders live temperature column when requested' do
    tool = tools(:active_xl_tool_a)

    render partial: 'jobs/tools',
           locals: {
             tools: [tool],
             live_tool_temps: { '0' => 215.0 },
             show_live_temps: true,
             section_label: 'Print heads used'
           }

    assert_select 'th', text: 'Now'
    assert_select 'td', text: '215.0 °C'
  end
end
