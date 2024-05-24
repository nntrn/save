# coding: utf-8
# Generate html pages from data in `_data/` and apply layout from `_layouts`
# Adapted from Adolfo Villafiorita and modified by @nntrn (github.com/nntrn)

module Jekyll
  module Sanitizer
    def sanitize_filename(name)
      if(name.is_a? Integer)
        return name.to_s
      end
      return name.tr(
        "ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÑñÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž",
        "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz"
      ).downcase.strip.gsub(/[\s]+/, '-').gsub(/[-]{1,}/, '-').gsub(/[^a-zA-Z0-9-]+/, '')
    end
  end

  class DataPage < Page
    include Sanitizer

    def initialize(site, base, index_files, dir, page_data_prefix, data, name, name_expr, title, title_expr, template, extension, debug)
      @site = site
      @base = base

      if name_expr
        record = data
        raw_filename = eval(name_expr)
        if raw_filename == nil
          return
        end
      else
        raw_filename = (index_files ? "index" : data[name]) 
        if raw_filename == nil
          return
        end
      end
      if title
        raw_title = data[title]
      end

      filename = sanitize_filename(raw_filename).to_s
      @dir = (data[dir] ? data[dir] : dir)
      @name = (index_files ? "index" : filename) + "." + extension.to_s

      self.process(@name)

      if @site.layouts[template].path.end_with? 'html'
        @path = @site.layouts[template].path.dup
      else
        @path = @site.layouts[template].path
        @path = File.join(@site.layouts[template].path, @site.layouts[template].name)
      end

      base_path = @site.layouts[template].path
      base_path.slice! @site.layouts[template].name
      self.read_yaml(base_path, @site.layouts[template].name)

      if page_data_prefix
        self.data[page_data_prefix] = data
      else
        if data.key?('name')
          data['_name'] = data['name']
        end
        self.data.merge!(data)
      end

    end
  end

  class JekyllDatapageGenerator < Generator
    safe true

    def generate(site)
      index_files = site.config['from_template-dirs'] == true

      data = site.config['from_template']
      if data
        data.each do |data_spec|
          index_files_for_this_data = data_spec['index_files'] != nil ? data_spec['index_files'] : index_files
          template         = data_spec['template'] || data_spec['data']
          name             = data_spec['name']
          name_expr        = data_spec['name_expr']
          title            = data_spec['title']
          title_expr       = data_spec['title_expr']
          dir              = data_spec['dir'] || data_spec['data']
          extension        = data_spec['extension'] || "html"
          page_data_prefix = data_spec['page_data_prefix']
          debug            = data_spec['debug']
          
          if not site.layouts.key? template
            puts "error (datapage-gen). could not find template #{template}. Skipping dataset #{name}."
          else
            records = nil

            data_spec['data'].split('.').each do |level|
              if records.nil?
                records = site.data[level]
              else
                records = records[level]
              end
            end
            if (records.kind_of?(Hash))
              records = records.values
            end

            records = records.select { |record| record[data_spec['filter']] } if data_spec['filter']
            records = records.select { |record| eval(data_spec['filter_condition']) } if data_spec['filter_condition']

            records.each do |record|
              site.pages << DataPage.new(site, site.source, index_files_for_this_data, dir, page_data_prefix, record, name, name_expr, title, title_expr, template, extension, debug)
            end
          end
        end
      end
    end
  end

  module DataPageLinkGenerator
    include Sanitizer

    def datapage_url(input, dir)
      extension = @context.registers[:site].config['from_template-dirs'] ? '/' : '.html'
      "#{dir}/#{sanitize_filename(input)}#{extension}"

      extension = @context.registers[:site].config['from_template-dirs'] ? '.md' : '.html'
    end
  end

end

Liquid::Template.register_filter(Jekyll::DataPageLinkGenerator)
