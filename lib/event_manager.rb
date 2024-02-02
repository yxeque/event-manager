require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  return "Missing or Invalid Phone Number" unless phone_number&.strip

  valid_number = phone_number.gsub(/[^0-9]/, '')
  return "Missing or Invalid Phone Number" unless [10, 11].include?(valid_number.length)
  return valid_number[1..-1] if valid_number.length == 11 && valid_number[0] == '1'

  valid_number
end

def extract_datetime(str)
  date, time = str.split(' ')

  begin
    date = Date.strptime(date, '%m/%d/%y')
    time = Time.strptime(time, '%H:%M')

    [date, time]
  rescue ArgumentError => e
    puts "Invalid date or time format: '", str, "'", "Error:", e.message
    nil
  end
end

def find_peak_hours(registrations)
  hour_registrations = Hash.new(0)
  total_registrations = 0

  registrations.each do |row|
    registration_datetime = extract_datetime(row[:regdate])
    next unless registration_datetime && registration_datetime.is_a?(Array) && registration_datetime[1]

    total_registrations += 1
    hour = registration_datetime[1].hour
    hour_registrations[hour] += 1
  end

  peak_hours = hour_registrations.select { |hour, count| count == hour_registrations.values.max }.map(&:first)

  puts "Peak Registration Hours:"
  puts "Hour | Registrations"
  puts "-" * 20
  hour_registrations.sort.each do |hour, count|
    hour_num = hour % 12
    hour_num = 12 if hour_num == 0
    am_pm = hour < 12 ? 'am' : 'pm'
    puts sprintf("%2d %s | %d", hour_num, am_pm, count)
  end
  puts "-" * 20
  puts sprintf("Total Registrations: %d", total_registrations)
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin 
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'Event Manager Initialized'


contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

peak_hours = find_peak_hours(contents)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  phone_number = clean_phone_number(row[:homephone])

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  # save_thank_you_letter(id, form_letter)

  puts "#{name} #{zipcode}: #{phone_number}"

end


