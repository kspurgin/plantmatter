require 'csv'
require 'json'
require 'net/http'
require 'pp'

require 'nokogiri'

class PmPlantData
  attr_reader :code
  attr_reader :data
  def initialize(catcode)
    @code = catcode
    @data = {}
    get_search_results unless File.file?("data/#{@code}.json")
    @data[:url] = extract_page_url
    get_page unless File.file?("data/#{@code}.html")
    @data[:sname] = get_data_from_html("span.current-item")
    @data[:cname] = get_data_from_html("h1 span")
    @data[:desc] = get_data_from_html("div.product-information--description")
    clean_desc
    @data[:sun] = get_json_facet_values('sun_exposure')
    @data[:water] = get_json_facet_values('soil_moisture')
    @data[:blooms] = get_json_facet_values('bloom_time')
    @data[:bloomcolor] = get_json_facet_values('bloom_color')
    @data[:advantages] = get_json_facet_values('ss_advantages')
    clean_advantages
    @data[:germ] = get_json_facet_values('ss_germination_code_facet')
    @data[:minheight] = get_json_height[0]
    @data[:maxheight] = get_json_height[1]
  end

  private

  def clean_advantages
    a = @data[:advantages].split('; ')
    a.each{ |adv| adv.sub!('Stars', 'Star') }
    @data[:advantages] = a.join('; ')
  end
  
  def get_json_height
    json = JSON.parse(File.read("data/#{@code}.json"))
    facets = json['facets'] #array of facet description hashes
    thisfacet = facets.select{ |e| e['field'] == 'search_spring_ht' }.first
    return thisfacet['range']
  end

  def get_json_facet_values(field)
    json = JSON.parse(File.read("data/#{@code}.json"))
    facets = json['facets'] #array of facet description hashes
    thisfacet = facets.select{ |e| e['field'] == field }.first
    if thisfacet
      values = thisfacet['values'].map{ |v| v['value'] }
      return values.join('; ')
    else
      return ''
    end
  end

  def clean_desc
    @data[:desc] = @data[:desc].gsub("\n", ' ')
    truncate_after = [
      'Dormant bare root plants ship each year.*',
      'This is a legume species.*',
      'Most legume species harbor.*',
      '\*This species.*',
      'Species of genus \w+ are legumes.*'
    ]
    
    truncate_after.each{ |val|
      @data[:desc] = @data[:desc].gsub(/#{val}/, '')
    }
    @data[:desc] = @data[:desc].gsub('.', '. ')
    @data[:desc] = @data[:desc].gsub(/  +/, ' ')
    @data[:desc].strip!
  end

  def get_search_results
    puts "Getting #{@code}..."
    url = URI("https://api.searchspring.net/api/search/search?siteId=qfh40u&q=#{@code}")
    response = Net::HTTP.get_response(url)
    if response.is_a?(Net::HTTPSuccess)
      File.open("data/#{@code}.json", 'w'){ |f|
        f.write(response.body)
      }
    else
      puts "Could not get search result for #{@code}"
      return nil
    end
    sleep 3
  end

  def extract_page_url
    json = JSON.parse(File.read("data/#{@code}.json"))
    return "https://www.prairiemoon.com#{json['singleResult']}"
  end

  def get_data_from_html(csspath)
    doc = Nokogiri::HTML(File.read("data/#{@code}.html"))
    return doc.css(csspath).text
  end

  def get_page
    puts "Getting page for #{@code}..."
    url = URI(@data[:url])
    response = Net::HTTP.get_response(url)
    if response.is_a?(Net::HTTPSuccess)
      File.open("data/#{@code}.html", 'w'){ |f|
        f.write(response.body)
      }
    else
      puts "Could not get #{url}"
      return nil
    end
    sleep 2
  end
end

codes = [
  'SOL12F',
'AST26F',
'LUP02F',
'PED02F',
'CAS52F',
'EUP04F',
'EUP08F',
'UVU04F',
'PHL04F',
'TAE02F',
'CIN08G',
'ANT04F',
'ASA02F',
'ARI02F',
'MER02F',
'POL02F',
'RUE02F',
'SCU06F',
'AND06G',
'SIS03F',
'SIS01F',
'SPO06G',
'ALL08F',
'AMS02F',
'AND08G',
'ANE12F',
'ANE10F',
'CAR18G',
'CAR63G',
'CEA02T',
'DIA01G',
'FRA10F',
'LIA14F',
'OSM03F'
  # 'ALL08F',
  # 'AMO04T',
  # 'ANA10F',
  # 'ANG02F',
  # 'APO02F',
  # 'ARA02F',
  # 'ASA02F',
  # 'BAP06F',
  # 'BRO06G',
  # 'CAM52F',
  # 'CIM02F',
  # 'HYD02F',
  # 'SMI02F',
  # 'OSM02F',
  # 'PAS02T',
  # 'POD02F',
  # 'POL52F',
  # 'PYC06F',
  # 'SAN02F',
  # 'SOL14F',
  # 'AST20F',
  # 'TEP02F',
  # 'THA04F',
  # 'VER72F'
]

codes.map!{ |code| PmPlantData.new(code) }


CSV.open('data/prairiemoon2021.csv', 'w'){ |csv|
  h = %w[name commonName description url sun waterAndSoil minHtFt maxHtFt bloomColor bloomTime advantages germCode catalogCode]
  csv << h
  codes.each{ |p|
    arr = [
      p.data[:sname],
      p.data[:cname],
      p.data[:desc],
      p.data[:url],
      p.data[:sun],
      p.data[:water],
      p.data[:minheight],
      p.data[:maxheight],
      p.data[:bloomcolor],
      p.data[:blooms],
      p.data[:advantages],
      p.data[:germ],
      p.code
    ]
    csv << arr
 }
}


# http://api.gbif.org/v1/species/match?name=Podophyllum%20peltatum&rank=SPECIES&kingdom=Plantae&verbose=true
