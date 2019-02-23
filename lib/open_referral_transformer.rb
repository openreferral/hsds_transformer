require "dotenv/load"
require "csv"
require "yaml"
require "pry"

class OpenReferralTransformer
  ORGANIZATION_HEADERS = %w(id name alternate_name description email url tax_status tax_id year_incorporated legal_status)
  LOCATION_HEADERS = %w(id organization_id name alternate_name description transportation latitude longitude)
  SERVICE_HEADERS = %w(id organization_id program_id name alternate_name description url email status interpretation_services application_process wait_time fees accreditations licenses)
  PHONE_HEADERS = %w(id location_id service_id organization_id contact_id service_at_location_id number extension type language description)

  attr_reader :organizations_path, :output_organizations_path, :locations_path, :output_locations_path,
              :services_path, :output_services_path, :mapping, :output_phones_path

  def self.run(args)
    new(args).transform
  end

  def initialize(args)
    @mapping = parse_mapping(args[:mapping])
    @organizations_path = args[:organizations]
    @locations_path = args[:locations]
    @services_path = args[:services]
    @output_organizations_path = "#{ENV["ROOT_PATH"]}/tmp/organizations.csv"
    @output_locations_path = "#{ENV["ROOT_PATH"]}/tmp/locations.csv"
    @output_services_path = "#{ENV["ROOT_PATH"]}/tmp/services.csv"
    @output_phones_path = "#{ENV["ROOT_PATH"]}/tmp/phones.csv"
  end

  def transform
    transform_organizations
    transform_locations
    transform_services

    return self
  end

  def transform_organizations
    org_mapping = mapping["organizations"]
    org_data = CSV.foreach(organizations_path, headers: true).each_with_object([]) do |input, array|
      row = {}
      valid = true
      org_mapping.each do |k, v|
        if v["required"] == true
          if input[k].nil?
            valid = false
            break
          end
        end
        if v["model"] == "organizations"
          key = v["field"]
          row[key] = input[k]
        end
      end
      if valid
        array << row
      end
    end

    write_csv(output_organizations_path, ORGANIZATION_HEADERS, org_data)
  end

  def transform_locations
    org_mapping = mapping["locations"]
    phone_data = []
    org_data = CSV.foreach(locations_path, headers: true).each_with_object([]) do |input, array|
      row = {}
      valid = true
      org_mapping.each do |k, v|
        if v["required"] == true
          if input[k].nil?
            valid = false
            break
          end
        end
        if v["model"] == "locations"
          key = v["field"]
          row[key] = input[k]
        elsif v["model"] == "phones"
          key = v["field"]
          # row[key] = input[k]
          phone_hash = {}
          phone_hash[key] = input[k]

          foreign_key = v["foreign_key_name"]
          foreign_key_value = v["foreign_key_value"]
          phone_hash[foreign_key] = input[foreign_key_value]
          phone_data << phone_hash

          # have a phones_array = [{location_id: Location_id, number: Phone number}]
        end
      end
      if valid
        array << row
      end
    end

    write_csv(output_locations_path, LOCATION_HEADERS, org_data)
    write_csv(output_phones_path, PHONE_HEADERS, phone_data)
  end

  def transform_services
    org_mapping = mapping["services"]
    org_data = CSV.foreach(services_path, headers: true).each_with_object([]) do |input, array|
      row = {}
      valid = true
      org_mapping.each do |k, v|
        if v["required"] == true
          if input[k].nil?
            valid = false
            break
          end
        end
        if v["model"] == "services"
          key = v["field"]
          row[key] = input[k]
        end
      end
      if valid
        array << row
      end
    end

    write_csv(output_services_path, SERVICE_HEADERS, org_data)
  end

  private

  def parse_mapping(mapping_path)
    YAML.load File.read(mapping_path)
  end

  def write_csv(path, headers, data)
    CSV.open(path, 'wb') do |csv|
      csv << headers
      data.each do |row|
        csv << CSV::Row.new(row.keys, row.values).values_at(*headers)
      end
    end
  end

end