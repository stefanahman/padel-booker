require 'capybara'
require 'capybara/dsl'

require 'selenium-webdriver'

Capybara.register_driver :local_headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.headless!
  options.add_argument('--no-sandbox')
  options.add_argument('--window-size=1920,1024')
  options.add_argument('--disable-gpu')
  options.add_argument('--disable-dev-shm-usage')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

class PadelBooker
  include Capybara::DSL

  attr_reader :session

  def initialize
    Capybara.default_driver = :local_headless_chrome
    @booking_date = Date.today
  end

  def start
    visit "https://www.matchi.se/facilities/padelzenterarsta?lang=en"
  end

  def scroll_down
    execute_script("window.scrollBy(0,700)")
  end

  def current_day
    @booking_date.day.to_s.rjust(2, '0')
  end

  def ready?
    find('#picker_daily').text.include?(current_day)
  end

  def wait
    until ready?
      sleep 0.1
    end
  end

  def next_day
    find('.ti-angle-right').click
    @booking_date = @booking_date.next_day
    wait
  end

  def previous_day
    find('.ti-angle-left').click
    @booking_date = @booking_date.previous_day
    wait
  end

  def toggle_date_picker
    find('#picker_daily').click
  end

  def jump_days(days = 14)
    days.times do
      next_day
    end
  end

  def courts
    all("table.daily > tbody > tr")[2..] # Exclude empty row + center court
  end

  def find_time(time)
    cell_index = time - 6

    court_times = courts.map do |court|
      court.all('table > tbody > tr > td.slot')[cell_index]
    end

    court_times.find do |court_time|
      court_time[:class].include?('free')
    end
  end

  def sign_in
    within 'nav' do
      click_on 'Log in'
    end

    fill_in 'username', with: ENV['USERNAME']
    fill_in 'password', with: ENV['PASSWORD']
    click_button 'Log in'
  end

  def confirm
    click_button 'Finish payment'
    sleep 5
  end

  def booking_success?
    has_content?("Thank you for your booking!")
  end

  def method_missing(method_name, *args, &block)
    send(method_name, args)
  end

  def respond_to_missing?(method_name, _include_private = false)
    true
  end
end

booker = PadelBooker.new

booker.start
booker.sign_in
booker.scroll_down
booker.jump_days(ENV['DAYS_IN_FUTURE'].to_i || 14)
time_slot = booker.find_time(ENV['TIME_OF_DAY'].to_i || 19)

if time_slot
  time_slot.click
  booker.confirm

  if booker.booking_success?
    puts "Your time has been booked"
  else
    puts "Unable to book"
  end
else
  puts "No free times"
  exit -1
end
