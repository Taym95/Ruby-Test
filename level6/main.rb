require 'json'
require 'rubygems'
require 'active_model'
require 'active_support/all'

# your code

INPUT_JSON_FILE = File.open('data.json').read

class Generator
  attr_accessor :input, :cars, :rentals, :rental_modifications
  
  def initialize(input_json_file)
    @input_json = JSON.parse(input_json_file)
    @cars = @input_json['cars'].map{
        |car| Car.new(car)
    }
    @rentals = @input_json['rentals'].map do |rental|
      Rental.new(rental.merge(car: @cars.find { |car| car.id == rental['car_id']}))
    end

    @rental_modifications = @input_json['rental_modifications'].map do |rental_modification|
      ModifiedRental.new(rental_modification.merge(rental: @rentals.find { |rental| rental.id == rental_modification['rental_id']}))
    end
  end
  
  def generate
    rentals.map(&:calculate_rental_price)
    rentals.map(&:generate_actions)
    rental_modifications.map(&:generate_modified_actions)
    self
  end
  
  def convert_to_json
    JSON.pretty_generate({ rental_modifications: rental_modifications.map(&:as_json) })
  end
end

# i used "ActiveModel::Model" because it  allows me to initialize the object with a hash of attributes.

class Car
  include ActiveModel::Model
  attr_accessor :id, :price_per_day, :price_per_km
end

class Rental
  include ActiveModel::Model
  attr_accessor :id, :car_id, :car, :start_date, :end_date, :distance, :price, :commission, :deductible_reduction, :options, :actions
  
  def initialize(*args)
    super(*args)
    @options = {deductible_reduction: 0}
    @actions = []
  end
  
  def rental_days
    (Date.parse(end_date) - Date.parse(start_date)).to_i + 1
  end
  
  def calculate_rental_price
    
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
    self.commission = Commission.new(self)
    
    if deductible_reduction
      options[:deductible_reduction] = 400 * rental_days
    end
  end
  
  def generate_actions
    return unless price
    actions << Transaction.new(who: 'driver', type: 'debit', amount: options[:deductible_reduction] + price)
    actions << Transaction.new(who: 'owner', type: 'credit', amount: price - commission.as_json.values.reduce(:+))
    commission.as_json.each do |c, v|
      commission_value = v
      commission_value += options[:deductible_reduction] if c == 'platform_fee'
      actions << Transaction.new(who: c.to_s.gsub(/_fee/, ''), type: 'credit', amount: commission_value)
    end
    
  end
  def as_json(*args)
    {id: id, actions: actions.map(&:as_json)}
  end
end

class ModifiedRental
  include ActiveModel::Model
  attr_accessor :id, :rental_id, :rental, :start_date, :end_date, :distance, :actions

  def initialize(*args)
    super(*args)
    @actions = []
  end

  def generate_modified_actions
  
    return unless rental.actions.present?
    new_rental = Rental.new(rental.as_json.merge(
        car: rental.car,
        start_date: start_date || rental.start_date,
        end_date: end_date || rental.end_date,
        distance: distance || rental.distance
    ))
    new_rental.calculate_rental_price
    new_rental.generate_actions
    Hash[rental.actions.map(&:as_json).zip(new_rental.actions.map(&:as_json))].each do |old, new|
      diff = new.as_json.deep_merge(old) { |k, a, b|
        if k == 'amount'
          v = a - b
          if v < 0
            k = :debit && -v
          else
            k = :credit && v
          end
        else
          a
        end
      }
      actions << Transaction.new(diff)
    end
    
  end

  def as_json(*args)
    { id: id, rental_id: rental_id, actions: actions.map(&:as_json) }
  end

end



class Commission
  include ActiveModel::Model
  attr_accessor :insurance_fee, :assistance_fee, :platform_fee, :global_commission
  
  def initialize(rental)
    @global_commission = rental.price*0.3
    @insurance_fee =(@global_commission*0.5).to_i
    @assistance_fee = rental.rental_days*100.to_i
    @platform_fee =(@global_commission - @insurance_fee - @assistance_fee).to_i
  end
  
  def as_json(*args)
    res = super
    res.delete('global_commission')
    res
  end
end


class Transaction
  include ActiveModel::Model
  attr_accessor :who, :type, :amount
end

result = Generator.new(INPUT_JSON_FILE).generate.convert_to_json

File.open('my_result_output6.json', 'w') { |file| file.write(result) }