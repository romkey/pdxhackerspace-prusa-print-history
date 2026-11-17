require 'test_helper'

module Prometheus
  class ExpositionTest < ActiveSupport::TestCase
    test 'renders unlabelled and labelled gauges' do
      out = Exposition.new
      out.gauge('thing', 'A thing.', 3)
      out.gauge('labelled', 'With labels.', [[{ a: 'x' }, 1], [{ a: 'y', b: 'z' }, 2.5]])

      assert_equal <<~TEXT, out.to_s
        # HELP thing A thing.
        # TYPE thing gauge
        thing 3
        # HELP labelled With labels.
        # TYPE labelled gauge
        labelled{a="x"} 1
        labelled{a="y",b="z"} 2.5
      TEXT
    end

    test 'escapes label values' do
      out = Exposition.new
      out.gauge('m', 'h', [[{ printer: %(Say "hi"\\\nnow) }, 1]])

      assert_includes out.to_s, 'm{printer="Say \"hi\"\\\\\nnow"} 1'
    end

    test 'renders cumulative gauges' do
      out = Exposition.new
      out.cumulative_gauge('d', 'Durations.', buckets: [10, 20], values: [5, 15, 15, 99])
      text = out.to_s

      assert_includes text, '# TYPE d gauge'
      assert_includes text, 'd{le="10"} 1'
      assert_includes text, 'd{le="20"} 3'
      assert_includes text, 'd{le="+Inf"} 4'
    end

    test 'renders NaN for nil values' do
      out = Exposition.new
      out.gauge('n', 'h', nil)

      assert_includes out.to_s, 'n NaN'
    end
  end
end
