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
  date = Date.strptime(date_str, '%d-%m-%Y') rescue nil
  time = Time.strptime(time_str, '%H:%M:%S') rescue nil if date

  [date, time]
end

def find_peak_hours(registrations)
  hour_counts = Array.new(24, 0)
  total_registrations = 0

  registrations.each do |row|
    total_registrations += 1
    datetime = extract_datetime(row[:regdate])
    next unless datetime && datetime[0]
  
    hour = datetime[0].time.hour
    hour_counts[hour] += 1
    puts hour_counts
  end

  max_count = hour_counts.max
  puts max_count
  peak_hours = hour_counts.each_with_index.find { |count, hour| count == max_count }&.last
  puts peak_hours

  puts "Total registrations: #{total_registrations}"

  if hour_counts.any?(&:positive?)
    peak_hours_formatted = peak_hours.map do |hour|
      if hour == 0
        "12 am"
      elsif hour < 12
        "#{hour} am"
      elsif hour == 12
        "noon"
      else
        "#{hour - 12} pm"
      end
    end

    puts "Peak hours: #{peak_hours_formatted.join(', ')} (with #{max_count} registrations each)"
  else
    puts "No peak hours found"
  end

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


