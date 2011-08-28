require 'test_helper'
require 'rails/performance_test_help'

class BenchmarkingTest < ActionDispatch::IntegrationTest
  module Metrics
    class Base
      def name
        "base"
      end

      def initialize
        @total = 0
      end
      attr_reader :total

      def benchmark
        before = measure
        yield
        @total += (measure - before)
      end
    end

    class Time < Base
      def name; "time"; end

      def measure
        ::Time.now
      end

      def format(measurement)
        if measurement < 1
          '%d ms' % (measurement * 1000)
        else
          '%.2f sec' % measurement
        end
      end
    end

    class WallTime < Time
      def name; "wall_time"; end

      def measure
        RubyProf.measure_process_time
      end
    end
  end

  class << self
    def output_dir(set=nil)
      if set
        @output_dir = set
      else
        @output_dir || "tmp/benchmarking"
      end
    end

    def metric_classes(set = nil)
      if set
        @metric_classes = set
      else
        @metric_classes || [Metrics::WallTime]
      end
    end

    def run_counts(set = nil)
      if set
        @run_counts = set
      else
        @run_counts || [10, 100, 500, 1000, 2000, 5000]
      end
    end
  end

  def full_test_name
    "#{self.class.name}##{method_name}"
  end

  def run(result)
    return if method_name =~ /^default_test$/
      yield(self.class::STARTED, name)
    @_result = result

    run_warmup

    self.class.metric_classes.each do |klass|
      run_profile(klass.new)
      result.add_run
    end

    yield(self.class::FINISHED, name)
  end

  def record(metric, count, measurement)
    now = Time.now.utc.xmlschema
    with_output_file(metric) do |file|
      file.puts [count, measurement, now].join("\t")
    end
  end

  HEADER = 'count,measurement,created_at'

  def with_output_file(metric)
    fname = File::join(self.class.output_dir, "#{full_test_name}_#{metric.name}.out")

    if new = !File.exist?(fname)
      FileUtils.mkdir_p(File.dirname(fname))
    end

    File.open(fname, 'ab') do |file|
      yield file
    end
  end

  def run_warmup
    GC.start

    time = Metrics::Time.new
    run_test do
      time.benchmark { __send__ @method_name }
    end
    puts "%s (%s warmup)" % [full_test_name, time.format(time.total)]

    GC.start
  end

  def run_profile(metric)
    results = []

    run_test do
      ([0] + self.class.run_counts).each_cons(2) do |so_far, upto|
        (upto - so_far).times do
          metric.benchmark { __send__ @method_name }
        end
        results << [upto, metric.total]
      end
    end

    results.each do |count, total|
      record(metric, count, total)
    end
  end

  def run_test
    run_callbacks :setup
    setup

    yield

  rescue ::Test::Unit::AssertionFailedError => e
    add_failure(e.message, e.backtrace)
  rescue StandardError, ScriptError => e
    add_error(e)
  ensure
    begin
      teardown
      run_callbacks :teardown, :enumerator => :reverse_each
    rescue ::Test::Unit::AssertionFailedError => e
      add_failure(e.message, e.backtrace)
    rescue StandardError, ScriptError => e
      add_error(e)
    end
  end

end


class FolksTest < BenchmarkingTest
  if ENV['BASE_RAILS'] == "true"
    output_dir('tmp/base_benchmarking')
  end

  define_method "test_index" do
    get '/folks'
  end
end
