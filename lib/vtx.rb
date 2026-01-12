# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/vtx/events.rb")
loader.ignore("#{__dir__}/vtx/parser")
loader.setup

require_relative "vtx/events"

begin
  RUBY_VERSION =~ /(\d+\.\d+)/
  require "vtx/parser/#{Regexp.last_match(1)}/vtx_parser"
rescue LoadError
  require "vtx/parser/vtx_parser"
end

module Vtx
  class Error < StandardError; end
end
