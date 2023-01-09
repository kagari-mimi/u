require "open-uri"
require "json"
require "rss"
require "cgi"

YURI_TAG_ID = -"a3c67850-4684-404e-9b7f-c69850ee5da6"
BASE_CHAPTER_URL = -"https://api.mangadex.org/chapter"
BASE_MANGA_URL = -"https://api.mangadex.org/manga"
CHAPTER_QUERY_STRING = %w[
  includeEmptyPages=0
  includeExternalUrl=0
  includeFuturePublishAt=0
  includeFutureUpdates=0
  includes[]=manga
  includes[]=scanlation_group
  limit=100
  order[readableAt]=desc
  translatedLanguage[]=en
].join("&")

manga_ids = []
authors = {}
artists = {}
cover_arts = {}

# Fetch a list of chapters and filter out ones without GL tag
chapters_url = "#{BASE_CHAPTER_URL}?#{CHAPTER_QUERY_STRING}"
chapters = JSON.parse(URI.parse(chapters_url).open.read)["data"].select do |chapter|
  manga = chapter["relationships"].detect { |relationship| relationship["type"] == "manga" }

  if manga["attributes"]["tags"].detect { |tag| tag["id"] == YURI_TAG_ID }
    manga_ids << manga["id"]
  end
end

# pp chapters
# pp manga_ids

# Fetch a list of mangas for additional metadata (author, artist, cover art)
mangas_query_string = (
  %w[
    includes[]=cover_art
    includes[]=author
    includes[]=artist
    limit=100
  ] +
  manga_ids.map { |manga_id| "ids[]=#{manga_id}" }
).join("&")
mangas_url = "#{BASE_MANGA_URL}?#{mangas_query_string}"
JSON.parse(URI.parse(mangas_url).open.read)["data"].each do |manga|
  manga["relationships"].each do |relationship|
    case relationship["type"]
    when "author"
      authors[manga["id"]] ||= []
      authors[manga["id"]] << relationship
    when "artist"
      artists[manga["id"]] ||= []
      artists[manga["id"]] << relationship
    when "cover_art"
      cover_arts[manga["id"]] ||= []
      cover_arts[manga["id"]] << relationship
    end
  end
end

# pp authors
# pp artists
# pp cover_arts

# Build actual feed
atom = RSS::Maker.make("atom") do |maker| # rubocop:disable Metrics/BlockLength
  maker.channel.authors.new_author do |author|
    author.name = "kagari-mimi/u - MangaDex Girls' Love Feed Generator"
    author.uri = "https://github.com/kagari-mimi/u"
  end

  maker.channel.id = "https://mangadex.org/tag/a3c67850-4684-404e-9b7f-c69850ee5da6/girls-love"
  maker.channel.title = "Latest Girls' Love Chapters from MangaDex"
  maker.channel.updated = chapters.first["attributes"]["updatedAt"]

  chapters.each do |chapter| # rubocop:disable Metrics/BlockLength
    manga = chapter["relationships"].detect { |relationship| relationship["type"] == "manga" }

    title = manga["attributes"]["title"]["en"]
    title << " Vol.#{chapter['attributes']['volume']}" if chapter["attributes"]["volume"]
    title << " Ch.#{chapter['attributes']['chapter']}" if chapter["attributes"]["chapter"]
    title << " #{chapter['attributes']['title']}" if chapter["attributes"]["title"]

    cover_art = %W[
      https://mangadex.org/covers/
      #{manga['id']}/
      #{cover_arts[manga['id']][0]['attributes']['fileName']}.256.jpg
    ].join

    scanlation_groups = chapter["relationships"].filter_map do |relationship|
      next unless relationship["type"] == "scanlation_group"

      %(<a href="https://mangadex.org/group/#{relationship['id']}">#{CGI.escapeHTML(relationship['attributes']['name'])}</a>)
    end.join(", ")

    tags = manga["attributes"]["tags"].map do |tag|
      %(<a href="https://mangadex.org/tag/#{tag['id']}">#{CGI.escapeHTML(tag['attributes']['name']['en'])}</a>)
    end

    content_rating = manga["attributes"]["contentRating"]
    if content_rating != "safe"
      tags.unshift %(<a href="https://mangadex.org/titles?content=#{content_rating}"><strong>#{content_rating.upcase}</strong></a>)
    end

    tags = tags.join(", ")

    maker.items.new_item do |item| # rubocop:disable Metrics/BlockLength
      item.id = "https://mangadex.org/chapter/#{chapter['id']}"
      item.title = title
      item.link = item.id
      item.updated = chapter["attributes"]["updatedAt"]

      if authors[manga["id"]].map { _1["id"] } == artists[manga["id"]].map { _1["id"] }
        authors[manga["id"]].each do |author|
          item.authors.new_author do |author_item|
            author_item.name = CGI.escapeHTML(author["attributes"]["name"])
            author_item.uri = "https://mangadex.org/author/#{author['id']}"
          end
        end
      else
        authors[manga["id"]].each do |author|
          item.authors.new_author do |author_item|
            author_item.name = "#{CGI.escapeHTML(author['attributes']['name'])} (Author)"
            author_item.uri = "https://mangadex.org/author/#{author['id']}"
          end
        end

        artists[manga["id"]].each do |artist|
          item.authors.new_author do |artist_item|
            artist_item.name = "#{CGI.escapeHTML(artist['attributes']['name'])} (Artist)"
            artist_item.uri = "https://mangadex.org/author/#{artist['id']}"
          end
        end
      end

      item.content.content = <<~HTML
        <p>
          <img src="#{cover_art}"/>
        </p>
        <p>
          <strong>Scanlation Group:</strong>
          #{scanlation_groups}
        </p>
        <p>
          <strong>Tags:</strong>
          #{tags}
        </p>
      HTML
    end
  end
end

puts atom
