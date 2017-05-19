require 'json'
require 'rubygems'
require 'active_model'
require 'active_support/all'

# your code

INPUT_JSON_FILE = File.open('data.json').read

class Generator
  attr_accessor :input, :cars, :rentals
  
  def initialize(input_json_file)
    @input_json = JSON.parse(input_json_file)
    @cars = @input_json['cars'].map{
        |car| Car.new(car)
    }
    @rentals = @input_json['rentals'].map do |rental|
      Rental.new(rental.merge(car: @cars.find { |car| car.id == rental['car_id']}))
    end
  end
  
  def generate
    rentals.map(&:calculate_rental_price)
    self
  end
  
  def convert_to_json
    JSON.pretty_generate({ rentals: rentals.map(&:output_json) })
  end
end

# i used "ActiveModel::Model" because it  allows me to initialize the object with a hash of attributes.

class Car
  include ActiveModel::Model
  attr_accessor :id, :price_per_day, :price_per_km
end

class Rental
  include ActiveModel::Model
  attr_accessor :id, :car_id, :car, :start_date, :end_date, :distance, :price
  
  def calculate_rental_price
    rental_days = (Date.parse(end_date) - Date.parse(start_date)).to_i + 1
    rental_day_price = 0
    (1..rental_days).to_a.each_with_index do |i, _|
      rental_day_price += case
                     when i > 10 then car.price_per_day * 0.5
                     when i > 4 then car.price_per_day * 0.7
                     when i > 1 then car.price_per_day * 0.9
                     else
                       car.price_per_day
                   end
    end
   
    self.price =  (rental_day_price +
        distance * car.price_per_km).to_i
  end
  
  def output_json(*args)
    {id: id, price: price}
  end
end

result = Generator.new(INPUT_JSON_FILE).generate.convert_to_json

File.open('my_result_output2.json', 'w') { |file| file.write(result) }