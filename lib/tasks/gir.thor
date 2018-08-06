# Created By:
# Philip Chimento // ptomato
# Evan Welsh // rockon999

require 'rexml/document'
require 'fileutils'
require 'xdg'

# Command-line tools for creating scrapers from GIR files
class GirCLI < Thor
  def self.to_s
    'Gir'
  end

  def initialize(*args)
    require 'docs'
    super
  end

  desc 'generate_all', 'Generate scrapers from all installed GIR files'
  def generate_all(gir_dir = nil)
    if gir_dir
      glob = Dir.glob(gir_dir + '/gir-1.0/*.gir')
    else
      glob = XDG['DATA_DIRS'].glob('gir-1.0/*.gir')
    end
    glob.each do |path|
      puts 'Generating scraper for ' + File.basename(path) + '...'
      begin
        generate path
      rescue REXML::ParseException
        puts 'Failed to generate scraper for... ' + File.basename(path) + '...'
      end
    end
  end

  desc 'generate', 'Generate a scraper from a GIR file'
  def generate(gir_path)
    gir = read_gir gir_path

    namespace = gir.root.elements['namespace']
    scraper_info = process_namespace namespace
    scraper_info[:slug] = generate_slug scraper_info
    scraper_info[:version] = compute_version gir, scraper_info
    write_scraper gir_path, scraper_info
  end

  no_commands do
    def read_gir(path)
      gir_file = File.new path
      gir = REXML::Document.new gir_file
      gir_file.close
      gir
    end

    def process_namespace(namespace)
      {
        name: namespace.attributes['name'],
        api_version: namespace.attributes['version'],
        c_prefix: namespace.attributes['c:symbol-prefixes']
      }
    end

    def generate_slug(scraper_info)
      full_name = scraper_info[:name] + scraper_info[:api_version]
      full_name.downcase.strip.gsub(/[^\w-]/, '')
    end

    def determine_version(gir)
      %w(MAJOR MINOR MICRO).map do |name|
        selector = "string(//constant[@name='#{name}_VERSION']/@value)"
        component = REXML::XPath.first gir, selector
        # Try a more lenient search - would match e.g. GDK_PIXBUF_MAJOR
        selector = "string(//constant[contains(@name, '#{name}')]/@value)"
        component = REXML::XPath.first gir, selector if component == ''
        fail 'No version found' if component == ''
        component
      end.join '.'
    rescue
      nil
    end

    def guess_version(gir)
      selector = '//namespace/*[@version]/@version'
      versions = REXML::XPath.match(gir, selector).map do |ver|
        Gem::Version.new(ver.to_s.chomp '.')  # they can have stray periods
      end
      return nil if versions == []
      versions.max.to_s << '+'
    end

    def compute_version(gir, scraper_info)
      version = determine_version gir
      version = guess_version gir if version.nil?
      api_version = scraper_info[:api_version] + ' API'
      version = api_version if version.nil? || api_version[0] > version[0]
      version
    end

    def scraper_code(gir_path, info)
      gir_name = "#{info[:name]}-#{info[:api_version]}.gir"
      code = <<-END.strip_heredoc
    module Docs
      # Autogenerated scraper for #{gir_name}
      class #{info[:slug].capitalize} < Gir
#{info.keys.map { |k| "        self.#{k} = '#{info[k]}'" }.join "\n"}
        self.gir_path = '#{gir_path}'
        options[:attribution].sub! '{GIR_NAME}', '#{gir_name}'
      end
    end
      END
      code
    end

    def write_scraper(gir_path, info)
      scaper_dir = File.join 'lib', 'docs', 'scrapers', 'gnome', 'generated'
      scraper_name = File.join scaper_dir, info[:slug] + '.rb'

      # Ensure the 'generated' directory exists.
      FileUtils.mkdir_p scaper_dir

      out_file = File.new scraper_name, 'w'
      out_file.write scraper_code(gir_path, info)
    end
  end
end
