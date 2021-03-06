require 'will_paginate/array'
class SearchController < ApplicationController
  before_action :authenticate_user!

  def home

  end

  def search_artist
    @artist_name = params[:search_artist]
    if @artist_name.blank?
      flash[:notice] = "Please enter a name of artist before hitting 'GO'"
      redirect_to root_path
    else
      redirect_to list_artists_path(@artist_name)
    end
  end

  def list_artists
    $artist = lastfm.artist
    @artist_name = params[:artist_query]
    if @artist_name.blank?
      flash[:notice] = "Please enter a name of artist before hitting 'GO'"
    end
    resp = $artist.search(artist: params[:artist_query], limit: 10)
    if resp['status'] == 'ok'
      $more_artists = resp['results']['totalResults'].to_i - 10
      @artist_matched = resp['results']['artistmatches']['artist']
      $page_count = 1
      $previous_artists = 0
      if @artist_matched.nil?
        flash[:alert] = "No artist matched with given name. Please check the name again..."
        redirect_to root_path
      end
    else

    end
  end

  def get_next_page
    $more_artists = params[:remaining].to_i
    if $more_artists > 0
      $page_count += 1
      $more_artists -= 10
      $previous_artists += 10
      fetch_artists
    end
    respond_to do |format|
      format.js
      format.html
    end
  end

  def get_previous_page
    $previous_artists = params[:previous].to_i
    if $more_artists > 0
      $page_count -= 1
      $more_artists += 10
      $previous_artists -= 10
    end
    fetch_artists
    respond_to do |format|
      format.js
      format.html
    end
  end

  def show_artist
    artist_name = params[:artist_name]
    artist = lastfm.artist
    @resp = artist.get_info(artist: artist_name)

    visited_artist = VisitedArtist.find_by_name(artist_name)
    if visited_artist.nil?
      visited_artist = VisitedArtist.create(name: artist_name, image_url: @resp['image'][1]['content'])
      history = History.create(visited_artist_id: visited_artist.id, user_id: current_user.id, count: 1)
    else
      history = History.where(visited_artist_id: visited_artist.id, user_id: current_user.id).first
      if history.nil?
        history = History.create(visited_artist_id: visited_artist.id, user_id: current_user.id, count: 1)
      else
        count = history.count
        history.update_attributes(count: count + 1)
      end
    end

    tracks_info = artist.get_top_tracks(artist: artist_name, limit: 10)
    if tracks_info.is_a? Hash
      tracks = []
      tracks << tracks_info
    else
      tracks = tracks_info
    end

    albums_info = artist.get_top_albums(artist: artist_name, limit: 10)
    if albums_info.is_a? Hash
      albums = []
      albums << albums_info
    else
      albums = albums_info
    end
    @resp.merge!({"tracks" => tracks, "albums" => albums})
  end

  def get_similar
    @artist_name = params[:artist_name]
    temp_resp = lastfm.artist.get_similar(artist: params[:artist_name]).drop(1)
    @resp = temp_resp.paginate(page: params[:page], per_page: 10)
  end

  protected

  def lastfm
    lastfm = Lastfm.new(ENV['LAST_FM_API'], ENV['LAST_FM_SECRET'])
  end

  def fetch_artists
    @artist_name = params[:artist_query]
    resp = $artist.search(artist: params[:artist_query], limit: 10, page: $page_count)
    if resp['status'] == 'ok'
      @artist_matched = resp['results']['artistmatches']['artist']
    end
  end
end
