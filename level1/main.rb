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
    self.price = ((Date.parse(end_date) - Date.parse(start_date)).to_i + 1) * car.price_per_day +
        distance * car.price_per_km
  end
  
  def output_json(*args)
    {id: id, price: price}
  end
end

result = Generator.new(INPUT_JSON_FILE).generate.convert_to_json

File.open('my_result_output1.json', 'w') { |file| file.write(result) }