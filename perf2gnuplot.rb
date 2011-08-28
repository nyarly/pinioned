#!/bin/env ruby

require 'erb'

TARGET_DIR = "tmp/gnuplot"
DIR=ARGV[0]
TAG=ARGV[1]

raise "Need directory of performance data" unless DIR
raise "Need tag for data" unless TAG

results = Hash.new{|h,k| h[k] = Hash.new{|h,k| h[k] = []}}
Dir[File::join(DIR, "*")].each do |path|
  m = /#{DIR.sub(/\/$/,"")}\/(.*)_(\d+)_(.+).csv/.match(path)
  if m
    count = m[2].to_i
    File::open(path) do |file|
      file.gets
      file.each_line do |line|
        values = line.split(",")
        measurement = values[0]
        results[m[1]][m[3]] << [count, measurement.to_f]
      end
    end
  else
    p :no_match => path
  end
end

templ = ERB::new(File::read(File::expand_path("../templ/perf.p.erb", __FILE__)))
results.each_pair do |test_name, test_results|
  test_results.each_pair do |measure, values|
    filebase = "#{TAG}-#{test_name}-#{measure}"
    outfile = filebase + ".out"
    File::open(File::join(TARGET_DIR, outfile),"w")do |file|
      values.each do |count, result|
        file.puts "#{count}\t#{result}"
      end
    end

    gnuplot_file = filebase + ".p"
    File::open(File::join(TARGET_DIR, gnuplot_file), "w") do |file|
      file.write(templ.result(binding))
    end
  end
end

