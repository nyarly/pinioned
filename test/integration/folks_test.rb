require 'test_helper'
require 'perftools'

class FolksIntegrationTest < ActionDispatch::IntegrationTest
  def test_perf
    count = 10000
    output = "get_folks_profile_#{count}"
    if ENV['BASE_RAILS'] == "true"
      output = "br_" + output
    end

    PerfTools::CpuProfiler.start("tmp/#{output}") do
      count.times do
        get "/folks"
      end
    end
  end
end
