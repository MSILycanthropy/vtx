# frozen_string_literal: true

require "io/console"

$stdout.sync = false # ensure Ruby buffering is on

def stress_test_buffered
  $stdin.raw do
    print("\e[?1049h")  # alternate screen
    print("\e[2J")      # clear

    100.times do |frame|
      # Redraw entire "screen" each frame
      24.times do |row|
        print("\e[#{row + 1};1H")  # move to row
        print(" " * 80)            # clear line
        print("\e[#{row + 1};1H")  # move back
        print("Frame #{frame} - Row #{row} - #{rand(10000)}")
      end
      $stdout.flush

      sleep(0.016) # ~60fps
    end

    print("\e[?1049l") # leave alternate screen
  end
end

def stress_test_unbuffered
  $stdin.raw do
    $stdout.sync = true # force unbuffered

    print("\e[?1049h")
    print("\e[2J")

    100.times do |frame|
      24.times do |row|
        print("\e[#{row + 1};1H")
        print(" " * 80)
        print("\e[#{row + 1};1H")
        print("Frame #{frame} - Row #{row} - #{rand(10000)}")
      end

      sleep(0.016)
    end

    print("\e[?1049l")
  end
end

puts "Testing BUFFERED (sync=false)... press enter"
gets
stress_test_buffered

puts "Testing UNBUFFERED (sync=true)... press enter"
gets
stress_test_unbuffered
