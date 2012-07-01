require 'exifr'
require 'RMagick'
require 'yaml'
include Magick

include FileUtils

$image_extensions = [".png", ".jpg", ".jpeg", ".gif"]

module Jekyll
  class GalleryFile < StaticFile
    def destination(dest)
      File.join(dest, "#{@site.config['gallery_dir']}/#{@dir}", @name)
    end
  end

  class GalleryIndex < Page
    def initialize(site, base, dir, galleries)
      @site = site
      @base = base
      @dir = site.config['gallery_dir']
      @name = "index.html"

      self.process(@name)
      self.read_yaml(File.join(base, "_layouts"), "gallery_index.html")
      self.data["title"] = "Photos"
      self.data["galleries"] = []
      begin
        galleries.sort! {|a,b| b.data["date_time"] <=> a.data["date_time"]}
      rescue Exception => e
        puts e
        throw e
      end
      galleries.each {|gallery| self.data["galleries"].push(gallery.data)}
    end
  end

  class GalleryPage < Page
    def initialize(site, base, dir, gallery_name)
      @site = site
      @base = base
      @dir = "#{site.config['gallery_dir']}/#{gallery_name}"
      @name = "index.html"
      @images = []

      meta = YAML.load_file "#{dir}/meta.yml"

      best_image = nil
      max_size = 300
      self.process(@name)
      self.read_yaml(File.join(base, "_layouts"), "gallery_page.html")
      self.data["gallery"] = gallery_name
      gallery_title_prefix = site.config["gallery_title_prefix"] || ""

      self.data["name"] = gallery_name
      self.data["title"] = "#{gallery_title_prefix}#{meta["title"]}"
      self.data["photos"] = {}
      self.data["comments"] = meta["comments"]
      self.data["description"] = meta["description"]

      thumbs_dir = "#{base}/_galleries/#{gallery_name}/thumbs"
      FileUtils.mkdir_p thumbs_dir

      Dir.foreach(dir) do |image|
        if image.chars.first != "." and image.downcase().end_with?(*$image_extensions)
          @images.push(image)
          best_image = image

          if File.file?("#{thumbs_dir}/#{image}") == false or File.mtime("#{dir}/#{image}") > File.mtime("#{thumbs_dir}/#{image}")
            m_image = ImageList.new("#{dir}/#{image}")
            m_image.resize_to_fit!(max_size, max_size)
            puts "Writing thumbnail to #{thumbs_dir}/#{image}"
            m_image.write("#{thumbs_dir}/#{image}")
          end

          @site.static_files << GalleryFile.new(site, "#{base}/_galleries", "#{gallery_name}/thumbs", "#{image}")
          @site.static_files << GalleryFile.new(site, "#{base}/_galleries", gallery_name, image)

          self.data["photos"][image] = meta["photos"][image] || ""
        end
      end
      self.data["images"] = @images

      best_image = meta[:cover] if File.file? "#{dir}/#{meta[:cover]}"

      self.data["best_image"] = best_image
      self.data["date_time"] = EXIFR::JPEG.new("#{dir}/#{best_image}").date_time.to_i
    end
  end

  class GalleryGenerator < Generator
    safe true

    def generate(site)
      unless site.layouts.key? "gallery_index"
        return
      end
      # dir = site.config["gallery_dir"] || "_galleries"
      dir = "#{site.source}/_galleries"
      galleries = []

      Dir.foreach(dir) do |gallery_dir|
        gallery_path = File.join(dir, gallery_dir)
        if File.directory?(gallery_path) and gallery_dir.chars.first != "."
          gallery = GalleryPage.new(site, site.source, gallery_path, gallery_dir)
          gallery.render(site.layouts, site.site_payload)
          gallery.write(site.dest)
          site.pages << gallery
          galleries << gallery
        end
      end

      gallery_index = GalleryIndex.new(site, site.source, dir, galleries)
      gallery_index.render(site.layouts, site.site_payload)
      gallery_index.write(site.dest)
      site.pages << gallery_index
    end
  end
end
