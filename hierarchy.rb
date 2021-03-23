
# frozen_string_literal: true

require 'csv'
require 'json'
require 'net/http'

require 'pry'

# Reads CSV of plant names
# Expects one column
class PlantNameList
  def initialize(path)
    @path = path
  end

  def list
    @list ||= raw_list.map{ |name| PlantName.new(name) } 
  end
  
  def raw_list
    @raw_list ||= prep_list
  end
  
  private
  
  def prep_list
    table = CSV.parse(File.read(@path), headers: true)
    table.by_col[0]
  end
end

class PlantName
  def initialize(string)
    @orig_string = string
  end

  def binomial
    @orig_string.split[0..1].join(' ')
  end
  
  def cultivar
    matchdata = @orig_string.match(/('.*')/)
    matchdata.nil? ? '' : matchdata[1]
  end

  def gbif_species
    @gbif_species ||= GbifSpecies.new(binomial)
  end

  def gbif_species_id
    @gbif_species.id
  end

end

class Classification
  attr_reader :phylum, :class, :order, :family, :genus
  def initialize(name_data)
    @phylum = name_data['phylum']
    @class = name_data['class']
    @order = name_data['order']
    @family = name_data['family']
    @genus = name_data['genus']
  end

  def to_s
    [@phylum, @class, @order, @family, @genus].join(' > ')
  end
end

class GbifSpecies
  BASEURI = 'https://api.gbif.org/v1/species/match?verbose=true&kingdom=Plantae&name='
  def initialize(binomial)
    @data = get(binomial)
  end

  def id
    return if @data.empty?
    @data['speciesKey']
  end
  
  def classification
    return if @data.empty?
     Classification.new(@data)
  end
  
  def get(binomial)
    uri = URI("#{BASEURI}#{binomial}")
    response = Net::HTTP.get_response(uri)
    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

    puts "Could not get species data for #{binomial}"
    {}
  end
end

plantnames = 'data/plant_names.csv'
n = "Eryngium giganteum 'Miss Wilmott's Ghost'"

pn = PlantName.new(n)
gs = GbifSpecies.new(pn.binomial)
binding.pry

