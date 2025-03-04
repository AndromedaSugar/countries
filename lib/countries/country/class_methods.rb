# frozen_string_literal: true

require 'unaccent'

module ISO3166
  UNSEARCHABLE_METHODS = [:translations].freeze

  def self.Country(country_data_or_country)
    case country_data_or_country
    when ISO3166::Country
      country_data_or_country
    when String, Symbol
      ISO3166::Country.search(country_data_or_country)
    else
      raise TypeError, "can't convert #{country_data_or_country.class.name} into ISO3166::Country"
    end
  end

  module CountryClassMethods
    def new(country_data)
      super if country_data.is_a?(Hash) || codes.include?(country_data.to_s.upcase)
    end

    def codes
      ISO3166::Data.codes
    end

    def all(&blk)
      blk ||= proc { |_alpha2, d| ISO3166::Country.new(d) }
      ISO3166::Data.cache.map(&blk)
    end

    alias countries all

    def all_names_with_codes(locale = 'en')
      Country.all.map do |c|
        lc = (c.translation(locale) || c.iso_short_name)
        [lc.respond_to?('html_safe') ? lc.html_safe : lc, c.alpha2]
      end.sort
    end

    def pluck(*attributes)
      all.map do |country|
        attributes.map { |attribute| country.data.fetch(attribute.to_s) }
      end
    end

    def all_translated(locale = 'en')
      translations(locale).values
    end

    def translations(locale = 'en')
      locale = locale.downcase
      file_path = ISO3166::Data.datafile_path(%W[locales #{locale}.json])
      translations = JSON.parse(File.read(file_path))

      custom_countries = {}
      (ISO3166::Data.codes - ISO3166::Data.loaded_codes).each do |code|
        country = ISO3166::Country[code]
        translation = country.translations[locale] || country.iso_short_name
        custom_countries[code] = translation
      end

      translations.merge(custom_countries)
    end

    protected

    def strip_accents(string)
      if string.is_a?(Regexp)
        Regexp.new(Unaccent.unaccent(string.source), 'i')
      else
        Unaccent.unaccent(string.to_s).downcase
      end
    end

    # Some methods like parse_value are expensive in that they
    # create a large number of objects internally. In order to reduce the
    # object creations and save the GC, we can cache them in an class instance
    # variable. This will make subsequent parses O(1) and will stop the
    # creation of new String object instances.
    #
    # NB: We only want to use this cache for values coming from the JSON
    # file or our own code, caching user-generated data could be dangerous
    # since the cache would continually grow.
    def cached(value)
      @_parsed_values_cache ||= {}
      return @_parsed_values_cache[value] if @_parsed_values_cache[value]

      @_parsed_values_cache[value] = yield
    end
  end
end
